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
    subject { LogStash::Outputs::Chronix.new( "flush_size" => 3, "idle_flush_time" => 10 ) }

    let(:ttimestamp) { "1459353272" }
    let(:tmetric) { "test1" }
    let(:tvalue) { "10.5" }
    let(:events) { [LogStash::Event.new("metric" => tmetric, "value" => tvalue)] }

    it "should return a Chronix::Point" do
      point = subject.createChronixPoint(ttimestamp, tvalue)
      expectedResult = Chronix::Point.new( :t => ttimestamp, :v => tvalue )
      expect(point).to eq(expectedResult)
    end
 
    it "should return a zipped and base64 encoded string containing the data" do
      points = Chronix::Points.new
      points.p << subject.createChronixPoint(ttimestamp, tvalue)
      expectedResult = "H4sIAAAAAAAA/+Pi59jx9v12VkEGMFB1AACWVOXHEQAAAA=="
      expect(subject.zipAndEncode(points)).to eq(expectedResult)
    end

    it "should create a valid document" do
      points = Chronix::Points.new
      points.p << subject.createChronixPoint(ttimestamp, tvalue)
      phash = {"startTime" => ttimestamp, "endTime" => ttimestamp, "points" => points}
      document = subject.createSolrDocument(tmetric, phash)
      sampleDoc = { :metric => tmetric, :start => phash["startTime"], :end => phash["endTime"], :data => "H4sIAAAAAAAA/+Pi59jx9v12VkEGMFB1AACWVOXHEQAAAA==" }
      expect(document).to eq(sampleDoc)
    end

    it "should remove test documents" do
      solr.delete(tmetric)
      expect(solr.size).to eq(0)
    end
  end

  # these events are needed for the next two test-contexts
  e1 = LogStash::Event.new("metric" => "test1", "value" => "1.5")
  e2 = LogStash::Event.new("metric" => "test2", "value" => "2.5")
  e3 = LogStash::Event.new("metric" => "test1", "value" => "3.5")
  e4 = LogStash::Event.new("metric" => "test1", "value" => "4.5")
  e5 = LogStash::Event.new("metric" => "test2", "value" => "5.5")
  e6 = LogStash::Event.new("metric" => "test3", "value" => "6.5")
  e7 = LogStash::Event.new("metric" => "test1", "value" => "7.5")
  e8 = LogStash::Event.new("metric" => "test2", "value" => "8.5")

  context "adding and removing tests with different metrics" do
    subject { LogStash::Outputs::Chronix.new( "flush_size" => 1, "idle_flush_time" => 10 ) }

    let(:events) { [e1, e2, e3, e4, e5, e6, e7, e8] }

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

    let(:events) { [e1, e2, e3, e4, e5, e6, e7, e8] }

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
