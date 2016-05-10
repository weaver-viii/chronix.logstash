# encoding: utf-8

require_relative "../spec_helper"

describe LogStash::Outputs::Chronix do
  
  let(:solr) { subject.solr }

  before :each do
    subject.register

    events.each do |event|
      subject.receive(event)
    end
  end

  context "simple adding and removing test" do
    subject { LogStash::Outputs::Chronix.new( "flush_size" => 1, "idle_flush_time" => 10 ) }

    let(:tmetric) { "test1" }
    let(:events) { [LogStash::Event.new("metric" => tmetric, "value" => "1.5")] }

    it "create one event" do
      expect(solr.size).to eq(1)
    end

    it "should retrieve document" do
      doc = solr.get(tmetric)
      expect(doc[0][:data]).to_not be_nil
    end

    it "should remove document" do
      solr.delete(tmetric)
      expect(solr.size).to eq(0)
    end
  end

  context "test basic functions zip and encode, createPoint, createDocument" do
    # no flushing of the buffer needed, that's why we use 3 as flush_size here
    subject { LogStash::Outputs::Chronix.new( "threshold" => 10, "flush_size" => 3, "idle_flush_time" => 10 ) }

    let(:ttimestamp) { "1459353272" }
    let(:tmetric) { "test1" }
    let(:tvalue) { "10.5" }
    let(:events) { [LogStash::Event.new("metric" => tmetric, "value" => tvalue)] }

    it "should return a Chronix::Point" do
      point = subject.createChronixPoint(ttimestamp, tvalue)
      expectedResult = Chronix::Point.new( :t => ttimestamp, :v => tvalue )
      expect(point).to eq(expectedResult)
    end

    it "should return a Chronix::Point with :t == 0" do
      point = subject.createChronixPoint(0, tvalue)    
      expectedResult = Chronix::Point.new( :t => 0, :v => tvalue )
      expect(point).to eq(expectedResult)
    end
 
    it "should return a zipped and base64 encoded string containing the data" do
      points = Chronix::Points.new
      points.p << subject.createChronixPoint(ttimestamp, tvalue)
      expectedResult = "H4sIAAAAAAAA/+Pi59jx9v12VkEGMFB1AACWVOXHEQAAAA=="
      expect(subject.zipAndEncode(points)).to eq(expectedResult)
    end

    it "should create a correct point hash" do
      points = Chronix::Points.new
      points.p << subject.createChronixPoint(0, tvalue)
      phash = {tmetric => {"startTime" => ttimestamp.to_i, "lastTimestamp" => ttimestamp.to_i, "points" => points, "prevDelta" => 0, "timeSinceLastDelta" => 1, "lastStoredDate" => ttimestamp.to_i}}
      events = [LogStash::Event.new("metric" => tmetric, "value" => tvalue, "@timestamp" => "2016-03-30T15:54:32.172Z")]
      expect(subject.createPointHash(events)).to eq(phash)
    end

    it "should create a valid document" do
      points = Chronix::Points.new
      points.p << subject.createChronixPoint(ttimestamp, tvalue)
      phash = {"startTime" => ttimestamp, "lastTimestamp" => ttimestamp, "points" => points}
      document = subject.createSolrDocument(tmetric, phash)
      sampleDoc = { :metric => tmetric, :start => phash["startTime"], :end => phash["lastTimestamp"], :data => "H4sIAAAAAAAA/+Pi59jx9v12VkEGMFB1AACWVOXHEQAAAA==", :threshold => 10 }
      expect(document).to eq(sampleDoc)
    end

    it "should remove test documents" do
      solr.delete(tmetric)
      expect(solr.size).to eq(0)
    end
  end

  context "test delta calculation" do
    # no flushing of the buffer needed, that's why we use 3 as flush_size here
    subject { LogStash::Outputs::Chronix.new( "threshold" => 10, "flush_size" => 3, "idle_flush_time" => 10 ) }

    let(:tmetric) { "test1" }
    let(:tvalue) { "10.5" }
    let(:events) { [LogStash::Event.new("metric" => tmetric, "value" => tvalue)] }
    
    p_ev = []
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "1.0", "@timestamp" => "2016-05-10T15:00:10.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "2.0", "@timestamp" => "2016-05-10T15:00:20.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "3.0", "@timestamp" => "2016-05-10T15:00:30.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "4.0", "@timestamp" => "2016-05-10T15:00:39.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "5.0", "@timestamp" => "2016-05-10T15:00:48.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "6.0", "@timestamp" => "2016-05-10T15:00:57.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "7.0", "@timestamp" => "2016-05-10T15:01:06.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "8.0", "@timestamp" => "2016-05-10T15:01:15.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "9.0", "@timestamp" => "2016-05-10T15:01:24.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "10.0", "@timestamp" => "2016-05-10T15:01:33.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "11.0", "@timestamp" => "2016-05-10T15:01:42.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "12.0", "@timestamp" => "2016-05-10T15:01:51.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "13.0", "@timestamp" => "2016-05-10T15:02:00.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "14.0", "@timestamp" => "2016-05-10T15:02:09.000Z")
    p_ev << LogStash::Event.new("metric" => "test1", "value" => "15.0", "@timestamp" => "2016-05-10T15:02:18.000Z")

    it "delta should not be almost equals" do
      expect(subject.almostEquals(21, 10)).to be false
    end

    it "delta should be almost equals" do
      expect(subject.almostEquals(-18, -10)).to be true
    end

    it "should have no drift" do
      expect(subject.noDrift(10, 5, 1)).to be true
    end

    it "should have a drift" do
      expect(subject.noDrift(10, 5, 2)).to be false
    end

    it "should return a point hash" do
      pointHash = subject.createPointHash(p_ev)
#      puts pointHash
      expect(pointHash).to_not be_nil
    end
  end

  # these events are needed for the next two test-contexts
  e21 = LogStash::Event.new("metric" => "test1", "value" => "1.5")
  e22 = LogStash::Event.new("metric" => "test2", "value" => "2.5")
  e23 = LogStash::Event.new("metric" => "test1", "value" => "3.5")
  e24 = LogStash::Event.new("metric" => "test1", "value" => "4.5")
  e25 = LogStash::Event.new("metric" => "test2", "value" => "5.5")
  e26 = LogStash::Event.new("metric" => "test3", "value" => "6.5")
  e27 = LogStash::Event.new("metric" => "test1", "value" => "7.5")
  e28 = LogStash::Event.new("metric" => "test2", "value" => "8.5")

  context "adding and removing tests with different metrics" do
    subject { LogStash::Outputs::Chronix.new( "flush_size" => 1, "idle_flush_time" => 10 ) }

    let(:events) { [e21, e22, e23, e24, e25, e26, e27, e28] }

    it "should have 3 different metrics" do
      expect(solr.size).to eq(3)
    end

    it "should have 8 documents" do
      expect(solr.numDocuments).to eq(8)
    end

    it "should have 4 documents with metric 'test1'" do
      expect(solr.size("test1")).to eq(4)
    end

    it "should have 3 documents with metric 'test2'" do
      expect(solr.size("test2")).to eq(3)
    end

    it "should have 1 document with metric 'test3'" do
      expect(solr.size("test3")).to eq(1)
    end

    it "should remove all documents" do
      solr.delete
      expect(solr.size).to eq(0)
    end
  end

  # test1[0]: 3 elem, test1[1]: 1 elem
  # test2[0]: 1 elem, test2[1]: 2 elem
  # test3[0]: 1 elem
  context "adding and removing tests with different metrics and buffer-settings" do

    subject { LogStash::Outputs::Chronix.new( "flush_size" => 4, "idle_flush_time" => 10 ) }

    let(:events) { [e21, e22, e23, e24, e25, e26, e27, e28] }

    it "should have 3 different metrics" do
      expect(solr.size).to eq(3)
    end

    it "should have 5 documents" do
      expect(solr.numDocuments).to eq(5)
    end

    it "should have 2 documents with metric 'test1'" do
      expect(solr.size("test1")).to eq(2)
    end

    it "should have 2 documents with metric 'test2'" do
      expect(solr.size("test2")).to eq(2)
    end

    it "should have 1 document with metric 'test3'" do
      expect(solr.size("test3")).to eq(1)
    end

    it "get all documents with metric 'test1', compare data-fields, the first one should be longer than the second one" do
      res1 = solr.get("test1")
      expect(res1[0][:data].length).to be > res1[1][:data].length
    end

    it "compare data-field-lengths from 'test1' and 'test2', expect res1[0].length > res2[1].length" do
      res1 = solr.get("test1")
      res2 = solr.get("test2")
      expect(res1[0][:data].length).to be > res2[1][:data].length
    end

    it "compare data-field-lengths from 'test2', expect res2[1].length > res2[0].length" do
      res2 = solr.get("test2")
      expect(res2[1][:data].length).to be > res2[0][:data].length
    end

    it "compare data-field-lengths from 'test1' and 'test3', expect res1[1].length == res3[0].length" do
      res1 = solr.get("test1")
      res3 = solr.get("test3")
      expect(res1[1][:data].length).to equal(res3[0][:data].length)
    end 

    it "should remove all documents" do
      solr.delete
      expect(solr.size).to eq(0)
    end
  end

end
