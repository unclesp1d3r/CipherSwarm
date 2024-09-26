# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# /Users/kmelton/Projects/CipherSwarm/spec/jobs/calculate_mask_complexity_job_test.rb

require 'rails_helper'

RSpec.describe CalculateMaskComplexityJob, type: :job do
  describe '#perform_now' do
    subject(:perform_now) do
      described_class.perform_now(mask_list_id)
    end

    let(:mask_list) { create(:mask_list, complexity_value: 0) }
    let(:mask_list_id) { mask_list.id }

    context 'when the mask list does not exist' do
      let(:mask_list_id) { -1 }

      it 'does not raise an error' do
        expect { perform_now }.not_to raise_error
      end
    end

    context 'when the mask list has no file' do
      before do
        allow(mask_list).to receive(:file).and_return(nil)
      end

      it 'does not change the complexity value' do
        expect { perform_now }.not_to change(mask_list, :complexity_value).from(0)
      end
    end

    context 'when the mask list has a complexity value other than zero' do
      before do
        mask_list.update!(complexity_value: 5)
      end

      it 'does not change the complexity value' do
        expect { perform_now }.not_to change(mask_list, :complexity_value).from(5)
      end
    end

    context 'when there is a line with valid mask in the file' do
      let(:file) { fixture_file_upload('test_mask_file.hcmask', 'text/plain') }

      before do
        mask_list.update!(file: file)
      end

      # You may need to adjust this expectation depending on the contents of your file
      it 'updates the complexity value' do
        perform_now
        expect(mask_list.reload.complexity_value).to eq 10
      end
    end
  end
end
