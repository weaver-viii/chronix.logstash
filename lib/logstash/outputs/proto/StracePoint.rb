# NOT GENERATED

require 'protobuf/message'

module Chronix
  class StracePoint < ::Protobuf::Message
    optional :int64, :t, 1
    required :string, :v, 2
  end

  class StracePoints < ::Protobuf::Message
    repeated ::Chronix::StracePoint, :p, 1
  end
end
