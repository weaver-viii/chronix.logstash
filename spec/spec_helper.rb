require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/chronix"
require_relative "../lib/logstash/outputs/proto/Point.rb"
require_relative "chronix_helper"

class LogStash::Outputs::Chronix
  attr_reader :solr

  def connectToChronix
    @solr = Mocks::Chronix.new
  end
end
