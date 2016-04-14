module Mocks
  class Chronix

    def initialize
      @data = Hash.new
    end

    def add(documents)
      documents.each do |document|
        metric = document[:metric] 
        if @data[metric] == nil
          @data[metric] = Array.new
        end
        @data[metric] << document
      end
    end

    def get(metric)
      return @data[metric]
    end

    def delete(metric=nil)
      if metric == nil
        @data.each do |metric, data|
          @data.delete(metric)
        end
      else
        @data.delete(metric)
      end
    end

    def size(metric=nil)
      if metric == nil
        return @data.size
      else
        return @data[metric].size
      end
    end

    def numDocuments
      num = 0
      @data.each do |metric, data|
        num = num + data.size
      end
      return num
    end

    def update(data_hash)
    end
  end
end
