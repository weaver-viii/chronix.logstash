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
    # initialize the buffer
    buffer_initialize(
      :max_items => @flush_size,
      :max_interval => @idle_flush_time,
      :logger => @logger
    )

    connectToChronix
  end # def register

  # open the connection to chronix
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

    # add each event to our hash, sorted by metrics as key
    events.each do |event|

      eventData = event.to_hash()

      # format the timestamp to unix format
      timestamp = DateTime.iso8601("#{eventData["@timestamp"]}").to_time.to_i
      metric = eventData["metric"]

      # if there is no list for the current metric -> create a new one
      if pointHash[metric] == nil
        pointHash[metric] = {"startTime" => timestamp, "delta" => 0, "lastTimestamp" => timestamp, "points" => Chronix::Points.new}
      end

      delta = calculateDelta(timestamp, pointHash[metric]["lastTimestamp"])

      # insert the current point in our list
      pointHash[metric]["points"].p << createChronixPoint(delta, eventData["value"])

      # save current timestamp as lastTimestamp and the overall delta for the current metric
      pointHash[metric]["lastTimestamp"] = timestamp
      pointHash[metric]["delta"] = pointHash[metric]["delta"] + delta

    end #end do

    documents = []

    # iterate through pointHash and create a solr document
    pointHash.each { |metric, phash|
      documents << createSolrDocument(metric, phash)
    }

    # send to chronix
    @solr.add documents
    @solr.update :data => '<commit/>'
  end #def flush

  # this method zips and base64 encodes the list of points
  def zipAndEncode(points)
    # encode protobuf-list
    proto_bytes = points.encode
    string_io = StringIO.new("w")

    # compress the encoded protobuf-list
    gz = Zlib::GzipWriter.new(string_io)
    gz.write(proto_bytes)
    gz.close
    data = string_io.string

    # encode base64 (without \n)
    return Base64.strict_encode64(data)
  end

  def createChronixPoint(delta, value)
    return Chronix::Point.new( :t => delta, :v => value )
  end

  def createSolrDocument(metric, phash)
    endTime = phash["lastTimestamp"] # maybe use startTime + delta here?!
    return { :metric => metric, :start => phash["startTime"], :end => endTime, :data => zipAndEncode(phash["points"]) }
  end

  def calculateDelta(timestamp, lastTimestamp)
    threshold = 10
    offset = timestamp - lastTimestamp

    # if the current offset is less than threshold, return nil -> don't save the offset
    if offset <= threshold
      return 0
    else
      return offset
    end
  end

end # class LogStash::Outputs::Chronix
