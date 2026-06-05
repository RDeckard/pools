# frozen_string_literal: true

require "pools/ractor_pool"

module DoublerWorker
  def self.perform(number) = number * 2
end

module SumWorker
  def self.perform(a, b) = a + b
end

module BoomWorker
  def self.perform(_arg) = raise "kaboom"
end

module BusyWorker
  def self.perform(iterations)
    sum = 0
    i = 0
    while i < iterations
      sum += Math.sqrt(i)
      i += 1
    end
    sum.round(2)
  end
end

describe Pools::RactorPool do
  subject(:pool) { described_class.new(size: 4) }

  describe "#results" do
    it "runs every scheduled job and collects one outcome each" do
      pool.start
      8.times { |n| pool.schedule("DoublerWorker", n) }

      results = pool.results

      expect(results.size).to eq 8
      expect(results.map { |r| r[:result] }).to contain_exactly(0, 2, 4, 6, 8, 10, 12, 14)
    end

    it "passes multiple arguments through to #perform" do
      pool.start
      pool.schedule("SumWorker", 3, 4)

      expect(pool.results.first[:result]).to eq 7
    end

    it "captures exceptions raised by a job instead of losing them" do
      pool.start
      pool.schedule("DoublerWorker", 21)
      pool.schedule("BoomWorker", :anything)

      results = pool.results

      expect(results.count { |r| r.key?(:result) }).to eq 1
      expect(results.find { |r| r.key?(:error) }[:error]).to include "kaboom"
    end

    it "is idempotent" do
      pool.start
      pool.schedule("DoublerWorker", 1)

      expect(pool.results).to equal pool.results
    end
  end

  describe "scheduling" do
    it "dispatches jobs scheduled before #start" do
      pool.schedule("DoublerWorker", 5)
      pool.start
      pool.schedule("DoublerWorker", 6)

      expect(pool.results.map { |r| r[:result] }).to contain_exactly(10, 12)
    end

    it "tags each outcome with the worker that handled it" do
      pool.start
      8.times { pool.schedule("DoublerWorker", 1) }

      ractor_ids = pool.results.map { |r| r[:ractor] }.uniq

      expect(ractor_ids).to all(be_between(0, 3))
      expect(ractor_ids.size).to be > 1
    end
  end

  describe "parallelism" do
    it "is faster with more ractors on CPU-bound work" do
      iterations = 3_000_000

      single = described_class.new(size: 1).start
      4.times { single.schedule("BusyWorker", iterations) }
      single_at = Time.now
      single.results
      single_elapsed = Time.now - single_at

      quad = described_class.new(size: 4).start
      4.times { quad.schedule("BusyWorker", iterations) }
      quad_at = Time.now
      quad.results
      quad_elapsed = Time.now - quad_at

      expect(quad_elapsed).to be < single_elapsed
    end
  end
end
