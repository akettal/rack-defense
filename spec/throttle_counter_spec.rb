require_relative "spec_helper"

describe Rack::Defense::ThrottleCounter do
  before do
    @key = "192.168.0.1"
    @max_requests = 5
    @window = 5 * 1000
  end

  describe "#throttle?" do
    before do
      @counter = Rack::Defense::ThrottleCounter.new("upload_photo", @window, Redis.current)
    end

    it "allow request number max_requests if after period" do
      do_max_requests_minus_one(0, @max_requests)
      refute @counter.throttle? @key, @max_requests, @window + 1
    end

    it "block request number max_requests if in period" do
      do_max_requests(0, @max_requests)
      assert @counter.throttle? @key, @max_requests, (@window + 1000) - 1
    end

    it "allow consecutive valid periods" do
      (0..10).each { |i| do_max_requests_minus_one((@window + 1) * i, @max_requests) }
    end

    it "block consecutive invalid requests" do
      do_max_requests(0, @max_requests)
      (0..990).step(50).each do |i|
        assert @counter.throttle?(@key, @max_requests, @window + i)
      end
    end

    it "use a sliding window and do not count blocked requests" do
      do_max_requests(0, @max_requests)
      assert @counter.throttle?(@key, @max_requests, @window + 1000 - 1)
      refute @counter.throttle?(@key, @max_requests, @window + 2000)
    end

    it "should unblock after blocking requests" do
      do_max_requests(0, @max_requests)
      assert @counter.throttle? @key, @max_requests, @window
      refute @counter.throttle? @key, @max_requests, @window + 5 * 1000
    end
  end

  def do_max_requests_minus_one(offset, max_requests)
    (0..(@max_requests - 1)).map { |t| (t * 1_000) + offset }.each do |t|
      refute @counter.throttle?(@key, max_requests, t), "timestamp #{t}"
    end
  end

  def do_max_requests(offset, max_requests)
    do_max_requests_minus_one(offset, max_requests)
    last_ts = max_requests * 1_000 + offset
    refute @counter.throttle?(@key, max_requests, last_ts), "timestamp #{last_ts}"
  end
end
