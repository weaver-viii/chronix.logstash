# NOT GENERATED

require 'protobuf/message'

module Chronix
  class StringPoint < ::Protobuf::Message
    optional :int64, :t, 1
    required :string, :v, 2
  end

  class StringPoints < ::Protobuf::Message
    repeated ::Chronix::StringPoint, :p, 1
  end
end
