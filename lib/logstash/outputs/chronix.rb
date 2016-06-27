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
require_relative "proto/StracePoint.rb"

class LogStash::Outputs::Chronix < LogStash::Outputs::Base
  include Stud::Buffer

  config_name "chronix"

  # IP or hostname of chronix installation, default: localhost
  config :host, :validate => :string, :default => "localhost"

  # chronix port, default: 8983
  config :port, :validate => :string, :default => "8983"

  # path to chronix, default: /solr/chronix/
  config :path, :validate => :string, :default => "/solr/chronix/"

  # threshold for delta-calculation, every (delta - prev_delta) < threshold will be nulled
  config :threshold, :validate => :number, :default => 10

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
    pointHash = createPointHash(events)

    documents = []

    # iterate through pointHash and create a solr document
    pointHash.each { |metric, phash|
      documents << createSolrDocument(metric, phash)
    }

    # send to chronix
    @solr.add documents
    @solr.update :data => '<commit/>'
  end #def flush

  # this method iterates through all events and creates a hash with different lists of points sorted by metric
  def createPointHash(events)
    pointHash = Hash.new

    # add each event to our hash, sorted by metrics as key
    events.each do |event|

      eventData = event.to_hash()

      # format the timestamp to unix format
      timestamp = DateTime.iso8601("#{eventData["@timestamp"]}").to_time.to_i
      metric = eventData["metric"]

      # if there is no list for the current metric -> create a new one
      if pointHash[metric] == nil
        if eventData["chronix_type"] == "strace"
          pointHash[metric] = {"startTime" => timestamp, "lastTimestamp" => 0, "points" => Chronix::StracePoints.new, "prevDelta" => 0, "timeSinceLastDelta" => 0, "lastStoredDate" => timestamp}
        else
          pointHash[metric] = {"startTime" => timestamp, "lastTimestamp" => 0, "points" => Chronix::Points.new, "prevDelta" => 0, "timeSinceLastDelta" => 0, "lastStoredDate" => timestamp}
        end
      end

      if pointHash[metric]["lastTimestamp"] == 0
        delta = 0
      else
        delta = timestamp - pointHash[metric]["lastTimestamp"]
      end

      if (almostEquals(delta, pointHash[metric]["prevDelta"]) && noDrift(timestamp, pointHash[metric]["lastStoredDate"], pointHash[metric]["timeSinceLastDelta"]))
        # insert the current point in our list
        pointHash[metric]["points"].p << createChronixPoint(0, eventData["value"], eventData["chronix_type"])

        pointHash[metric]["timeSinceLastDelta"] += 1

      else
        # insert the current point in our list
        pointHash[metric]["points"].p << createChronixPoint(delta, eventData["value"], eventData["chronix_type"])

        pointHash[metric]["timeSinceLastDelta"] = 1
        pointHash[metric]["lastStoredDate"] = timestamp
      end

      # save current timestamp as lastTimestamp and the previousOffset
      pointHash[metric]["lastTimestamp"] = timestamp
      pointHash[metric]["prevDelta"] = delta

    end #end do

    return pointHash
  end

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

  def createChronixPoint(delta, value, type = "")
    if type == "strace"
      return Chronix::StracePoint.new( :t => delta, :v => value )
    else
      return Chronix::Point.new( :t => delta, :v => value )
    end
  end

  def createSolrDocument(metric, phash)
    endTime = phash["lastTimestamp"] # maybe use startTime + delta here?!
    # TODO add more meta-data
    return { :metric => metric, :start => phash["startTime"], :end => endTime, :data => zipAndEncode(phash["points"]) }
  end

  # checks if two offsets are almost equals
  def almostEquals(delta, prevDelta)
    diff = (delta - prevDelta).abs

    return (diff <= @threshold)
  end

  # checks if there is a drift
  def noDrift(timestamp, lastStoredDate, timeSinceLastDelta)
    calcMaxOffset = @threshold * timeSinceLastDelta
    drift = lastStoredDate + calcMaxOffset - timestamp.to_i

    return (drift <= (@threshold / 2))
  end

end # class LogStash::Outputs::Chronix
