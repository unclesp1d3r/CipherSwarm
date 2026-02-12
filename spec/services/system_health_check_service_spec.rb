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
end
