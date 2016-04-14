# encoding: utf-8

# based on: https://github.com/logstash-plugins/logstash-output-solr_http/blob/master/lib/logstash/outputs/solr_http.rb

require "base64"
require "date"
require "logstash/namespace"
require "logstash/outputs/base"
require "protobuf"
require "rsolr"
require "rubygems"
require "stud/buffer"
require "zlib"
require_relative "proto/Point.rb"

class LogStash::Outputs::Chronix < LogStash::Outputs::Base
  include Stud::Buffer

  config_name "chronix"

  # IP or hostname of chronix installation, default: localhost
  config :host, :validate => :string, :default => "localhost"

  # chronix port, default: 8983
  config :port, :validate => :string, :default => "8983"

  # path to chronix, default: /solr/chronix/
  config :path, :validate => :string, :default => "/solr/chronix/"

  # Number of events to queue up before writing to Solr
  config :flush_size, :validate => :number, :default => 100

  # Amount of time since the last flush before a flush is done even if
  # the number of buffered events is smaller than flush_size
  config :idle_flush_time, :validate => :number, :default => 30

  public
  def register
    buffer_initialize(
      :max_items => @flush_size,
      :max_interval => @idle_flush_time,
      :logger => @logger
    )

    connectToChronix
  end # def register

  def connectToChronix
    @url = "http://" + @host + ":" + @port + @path
    @solr = RSolr.connect :url => @url
  end # def connectToChronix

  public
  def receive(event)
    buffer_receive(event)
  end # def receive

  public
  def flush(events, close=false)
    pointHash = Hash.new

    events.each do |event|
      eventData = event.to_hash()
      timestamp = DateTime.iso8601("#{eventData["@timestamp"]}").to_time.to_i
      metric = eventData["metric"]

      if pointHash[metric] == nil
        pointHash[metric] = {"startTime" => timestamp, "endTime" => timestamp, "points" => Chronix::Points.new}
      end

      pointHash[metric]["endTime"] = timestamp
      pointHash[metric]["points"].p << createChronixPoint(timestamp, eventData["value"])

    end #end do
    
    documents = []
    # iterate through pointHash and zip all the data
    pointHash.each { |metric, phash|
      documents << createSolrDocument(metric, phash)
    }

    # send to chronix
    @solr.add documents
    @solr.update :data => '<commit/>'
  end #def flush

  def zipAndEncode(points)
    proto_bytes = points.encode
    string_io = StringIO.new("w")
    gz = Zlib::GzipWriter.new(string_io)
    gz.write(proto_bytes)
    gz.close
    data = string_io.string

    # encode base64 (without \n)
    return Base64.strict_encode64(data)
  end

  def createChronixPoint(timestamp, value)
    return Chronix::Point.new( :t => timestamp, :v => value )
  end

  def createSolrDocument(metric, phash)
    return { :metric => metric, :start => phash["startTime"], :end => phash["endTime"], :data => zipAndEncode(phash["points"]) }
  end

end # class LogStash::Outputs::Chronix
