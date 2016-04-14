# NOT GENERATED

require 'protobuf/message'

module Chronix
  class Point < ::Protobuf::Message
    optional :int64, :t, 1
    required :double, :v, 2
  end

  class Points < ::Protobuf::Message
    repeated ::Chronix::Point, :p, 1
  end
end
