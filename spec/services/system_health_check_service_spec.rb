# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe SystemHealthCheckService do
  subject(:service) { described_class.new }

  before do
    Sidekiq.redis { |conn| conn.del(described_class::LOCK_KEY) }
    Rails.cache.clear
  end

  describe "individual health checks" do
    describe "#check_minio (private)" do
      context "when MinIO is unreachable" do
        before do
          allow(ActiveStorage::Blob.service).to receive(:exist?)
            .with("health_check")
            .and_raise(StandardError.new("Connection refused"))
          allow(Rails.logger).to receive(:error)
        end

        it "returns unhealthy status" do
          result = service.send(:check_minio)
          expect(result[:status]).to eq(:unhealthy)
          expect(result[:error]).to include("Connection refused")
        end

        it "logs the error" do
          service.send(:check_minio)
          expect(Rails.logger).to have_received(:error).with(/MinIO check failed/)
        end
      end

      context "when MinIO is healthy" do
        before do
          allow(ActiveStorage::Blob.service).to receive(:exist?)
            .with("health_check")
            .and_return(false)
        end

        it "includes storage_used and bucket_count" do
          result = service.send(:check_minio)
          expect(result).to have_key(:storage_used)
          expect(result).to have_key(:bucket_count)
        end
      end

      context "when storage service supports buckets" do
        before do
          mock_service = Object.new.tap do |svc|
            svc.define_singleton_method(:exist?) { |_key| false }
            svc.define_singleton_method(:buckets) { [1, 2] }
          end
          allow(ActiveStorage::Blob).to receive(:service).and_return(mock_service)
        end

        it "returns bucket count" do
          result = service.send(:check_minio)
          expect(result[:bucket_count]).to eq(2)
        end
      end

      context "when MinIO extended metrics fail" do
        before do
          allow(ActiveStorage::Blob.service).to receive(:exist?)
            .with("health_check")
            .and_return(false)
          allow(ActiveStorage::Blob).to receive(:sum)
            .with(:byte_size)
            .and_raise(StandardError.new("metrics unavailable"))
          allow(Rails.logger).to receive(:warn)
        end

        it "returns healthy status with nil extended metrics" do
          result = service.send(:check_minio)
          expect(result[:status]).to eq(:healthy)
          expect(result[:storage_used]).to be_nil
          expect(result[:bucket_count]).to be_nil
        end
      end

      context "when storage service does not support buckets" do
        before do
          mock_service = Object.new.tap do |svc|
            svc.define_singleton_method(:exist?) { |_key| false }
            # No buckets method defined — respond_to?(:buckets) returns false
          end
          allow(ActiveStorage::Blob).to receive(:service).and_return(mock_service)
        end

        it "returns nil bucket_count" do
          result = service.send(:check_minio)
          expect(result[:status]).to eq(:healthy)
          expect(result[:bucket_count]).to be_nil
        end
      end
    end

    describe "#check_postgresql (private)" do
      context "when PostgreSQL is healthy" do
        it "includes connection_count and database_size" do
          result = service.send(:check_postgresql)
          expect(result[:status]).to eq(:healthy)
          expect(result).to have_key(:connection_count)
          expect(result).to have_key(:database_size)
        end
      end

      context "when PostgreSQL extended metrics fail" do
        before do
          allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original
          allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1").and_return(true)
          allow(ActiveRecord::Base.connection).to receive(:execute)
            .with(/pg_stat_database/)
            .and_raise(StandardError.new("permission denied"))
          allow(Rails.logger).to receive(:warn)
        end

        it "returns healthy status with nil extended metrics" do
          result = service.send(:check_postgresql)
          expect(result[:status]).to eq(:healthy)
          expect(result[:connection_count]).to be_nil
          expect(result[:database_size]).to be_nil
        end
      end

      context "when PostgreSQL stat queries return empty results" do
        before do
          allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original
          allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1").and_return(true)
          allow(ActiveRecord::Base.connection).to receive(:execute)
            .with(/pg_stat_database/)
            .and_return([])
          allow(ActiveRecord::Base.connection).to receive(:execute)
            .with(/pg_database_size/)
            .and_return([])
        end

        it "handles nil values from empty query results" do
          result = service.send(:check_postgresql)
          expect(result[:status]).to eq(:healthy)
          expect(result[:connection_count]).to be_nil
          expect(result[:database_size]).to be_nil
        end
      end
    end

    describe "#check_redis (private)" do
      context "when Redis is unreachable" do
        before do
          allow(Sidekiq).to receive(:redis).and_raise(StandardError.new("Connection refused"))
          allow(Rails.logger).to receive(:error)
        end

        it "returns unhealthy status" do
          result = service.send(:check_redis)
          expect(result[:status]).to eq(:unhealthy)
          expect(result[:error]).to include("Connection refused")
        end

        it "logs the error" do
          service.send(:check_redis)
          expect(Rails.logger).to have_received(:error).with(/Redis check failed/)
        end
      end

      context "when Redis is healthy" do
        it "includes used_memory, connected_clients, and hit_rate" do
          result = service.send(:check_redis)
          expect(result[:status]).to eq(:healthy)
          expect(result).to have_key(:used_memory)
          expect(result).to have_key(:connected_clients)
          expect(result).to have_key(:hit_rate)
        end
      end

      context "when Redis returns sparse info without keyspace data" do
        before do
          sparse_info = { "used_memory_human" => "1MB" }
          allow(Sidekiq).to receive(:redis).and_yield(
            double("redis_conn", info: sparse_info) # rubocop:disable RSpec/VerifiedDoubles
          )
        end

        it "handles nil keyspace values with nil hit_rate" do
          result = service.send(:check_redis)
          expect(result[:status]).to eq(:healthy)
          expect(result[:hit_rate]).to be_nil
          expect(result[:connected_clients]).to be_nil
        end
      end

      context "when Redis returns zero hits and zero misses" do
        before do
          zero_keyspace_info = {
            "used_memory_human" => "2MB",
            "connected_clients" => "5",
            "keyspace_hits" => "0",
            "keyspace_misses" => "0"
          }
          allow(Sidekiq).to receive(:redis).and_yield(
            double("redis_conn", info: zero_keyspace_info) # rubocop:disable RSpec/VerifiedDoubles
          )
        end

        it "returns nil hit_rate when total hits+misses is zero" do
          result = service.send(:check_redis)
          expect(result[:status]).to eq(:healthy)
          expect(result[:hit_rate]).to be_nil
          expect(result[:connected_clients]).to eq(5)
        end
      end
    end

    describe "#check_sidekiq (private)" do
      context "when Sidekiq stats are unavailable" do
        before do
          allow(Sidekiq::Stats).to receive(:new).and_raise(StandardError.new("Connection refused"))
          allow(Rails.logger).to receive(:error)
        end

        it "returns unhealthy status with zero defaults" do
          result = service.send(:check_sidekiq)
          expect(result[:status]).to eq(:unhealthy)
          expect(result[:error]).to include("Connection refused")
          expect(result[:workers]).to eq(0)
          expect(result[:queues]).to eq(0)
          expect(result[:enqueued]).to eq(0)
        end

        it "logs the error" do
          service.send(:check_sidekiq)
          expect(Rails.logger).to have_received(:error).with(/Sidekiq check failed/)
        end
      end
    end
  end

  describe "#application_info (private)" do
    context "when Sidekiq process check fails" do
      before do
        allow(Sidekiq::ProcessSet).to receive(:new).and_raise(StandardError.new("Connection refused"))
        allow(Rails.logger).to receive(:warn)
      end

      it "returns zero worker count" do
        result = service.send(:application_info)
        expect(result[:worker_count]).to eq(0)
        expect(result[:workers_running]).to be(false)
      end
    end
  end

  describe "#format_uptime (private)" do
    context "when uptime includes days and hours" do
      before do
        allow(Rails.application.config).to receive(:respond_to?).and_call_original
        allow(Rails.application.config).to receive(:respond_to?).with(:booted_at).and_return(true)
        allow(Rails.application.config).to receive(:booted_at).and_return(2.days.ago - 3.hours - 15.minutes)
      end

      it "formats with days, hours, and minutes" do
        result = service.send(:format_uptime)
        expect(result).to match(/2d/)
        expect(result).to match(/3h/)
        expect(result).to match(/15m/)
      end
    end

    context "when booted_at is not available" do
      before do
        allow(Rails.application.config).to receive(:respond_to?).and_call_original
        allow(Rails.application.config).to receive(:respond_to?).with(:booted_at).and_return(false)
      end

      it "returns unknown" do
        expect(service.send(:format_uptime)).to eq("unknown")
      end
    end
  end

  describe "#call" do
    before do
      allow(ActiveStorage::Blob.service).to receive(:exist?).with("health_check").and_return(false)
      stats = instance_double(Sidekiq::Stats, workers_size: 2, queues: { "default" => 0 }, enqueued: 5)
      allow(Sidekiq::Stats).to receive(:new).and_return(stats)
      allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
    end

    it "includes checked_at timestamp" do
      result = service.call
      expect(result[:checked_at]).to be_present
      expect { Time.iso8601(result[:checked_at]) }.not_to raise_error
    end

    it "includes application info" do
      result = service.call
      expect(result[:application]).to be_present
      expect(result[:application][:rails_version]).to eq(Rails.version)
      expect(result[:application][:ruby_version]).to eq(RUBY_VERSION)
    end

    it "logs lock acquired when performing all checks" do
      debug_messages = []
      allow(Rails.logger).to receive(:debug) do |*args, &block|
        debug_messages << (block ? block.call : args.first)
      end
      service.call
      expect(debug_messages).to include(match(/Lock acquired, performing all checks/))
    end
  end

  describe "Redis lock failure handling" do
    before do
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:debug)
    end

    context "when lock acquisition fails due to Redis error" do
      before do
        allow(Sidekiq).to receive(:redis).and_raise(StandardError.new("Redis connection refused"))
        allow(ActiveStorage::Blob.service).to receive(:exist?).with("health_check").and_return(false)
        stats = instance_double(Sidekiq::Stats, workers_size: 2, queues: { "default" => 0 }, enqueued: 5)
        allow(Sidekiq::Stats).to receive(:new).and_return(stats)
        allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
      end

      it "returns unhealthy Redis status" do
        result = service.call
        expect(result[:redis][:status]).to eq(:unhealthy)
        expect(result[:redis][:error]).to eq("Redis connection refused")
      end

      it "still performs non-Redis checks" do
        result = service.call
        expect(result[:postgresql][:status]).to eq(:healthy)
        expect(result[:minio][:status]).to eq(:healthy)
        expect(result[:sidekiq][:status]).to eq(:healthy)
      end

      it "includes application info and checked_at" do
        result = service.call
        expect(result[:application]).to be_present
        expect(result[:application][:rails_version]).to eq(Rails.version)
        expect(result[:checked_at]).to be_present
      end

      it "logs the lock acquisition failure" do
        service.call
        expect(Rails.logger).to have_received(:error).with(/Lock acquisition failed/)
      end

      it "logs that non-Redis checks are being run" do
        service.call
        expect(Rails.logger).to have_received(:warn).with(/Redis unavailable, running non-Redis checks only/)
      end
    end

    context "when lock is contended (another request holds the lock)" do
      before do
        Sidekiq.redis { |conn| conn.set(described_class::LOCK_KEY, "other_request", ex: described_class::LOCK_TTL) }
      end

      it "returns checking_status without marking Redis unhealthy" do
        result = service.call
        expect(result[:redis][:status]).to eq(:checking)
        expect(result[:redis][:error]).to be_nil
      end

      it "returns checking status for all services" do
        result = service.call
        %i[postgresql redis minio sidekiq].each do |check|
          expect(result[check][:status]).to eq(:checking)
        end
      end

      it "logs that lock is contended" do
        debug_messages = []
        allow(Rails.logger).to receive(:debug) do |*args, &block|
          debug_messages << (block ? block.call : args.first)
        end
        service.call
        expect(debug_messages).to include(match(/Lock contended, returning checking status/))
      end
    end

    context "when lock release fails due to Redis error" do
      before do
        allow(ActiveStorage::Blob.service).to receive(:exist?).with("health_check").and_return(false)
        stats = instance_double(Sidekiq::Stats, workers_size: 2, queues: { "default" => 0 }, enqueued: 5)
        allow(Sidekiq::Stats).to receive(:new).and_return(stats)
        allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
        allow(service).to receive(:release_lock).and_raise(StandardError.new("Redis connection lost")) # rubocop:disable RSpec/SubjectStub
      end

      it "returns results without raising" do
        result = service.call
        expect(result[:postgresql][:status]).to eq(:healthy)
      end

      it "logs the lock release failure" do
        service.call
        expect(Rails.logger).to have_received(:error).with(/Lock release failed/)
      end
    end
  end
end
