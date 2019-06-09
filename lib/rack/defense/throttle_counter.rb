# frozen_string_literal: true

module Rack
  class Defense
    class ThrottleCounter
      KEY_PREFIX = "rack-defense"

      attr_accessor :name

      def initialize(name, time_period, store)
        @name = name.to_s
        @time_period = time_period.to_i
        raise ArgumentError, "name should not be nil or empty" if @name.empty?

        raise ArgumentError, "time_period should be greater than zero" unless @time_period.positive?

        @store = store
      end

      def throttle?(key, max_requests, timestamp = nil)
        raise ArgumentError, "max_requests should be greater than zero (#{max_requests})" unless max_requests.positive?

        timestamp ||= (Time.now.utc.to_f * 1000).to_i
        args = [timestamp, max_requests, @time_period]
        res = @store.eval SCRIPT, ["#{KEY_PREFIX}:#{@name}:#{key}"], args
        !!res
      end

      SCRIPT = <<-LUA_SCRIPT
      local key = KEYS[1]
      local timestamp, max_requests, time_period = tonumber(ARGV[1]), tonumber(ARGV[2]), tonumber(ARGV[3])
      redis.call('ZREMRANGEBYSCORE', key, 0, math.max(0, timestamp - time_period))
      if tonumber(redis.call('ZCARD', key)) < max_requests
      then
        redis.call('ZADD', key, timestamp, timestamp)
        return false
      else
        return true
      end
      LUA_SCRIPT

      private_constant :SCRIPT
    end
  end
end
