# == Schema Information
#
# Table name: hashcat_statuses
#
#  id                                                       :bigint           not null, primary key
#  estimated_stop(The estimated time of completion)         :datetime
#  original_line(The original line from the hashcat output) :text
#  progress(The progress in percentage)                     :integer          is an Array
#  recovered_hashes(The number of recovered hashes)         :integer          is an Array
#  recovered_salts(The number of recovered salts)           :integer          is an Array
#  rejected(The number of rejected hashes)                  :integer
#  restore_point(The restore point)                         :integer
#  session(The session name)                                :string
#  status(The status code)                                  :integer
#  target(The target file)                                  :string
#  time(The time of the status)                             :datetime
#  time_start(The time the task started)                    :datetime
#  created_at                                               :datetime         not null
#  updated_at                                               :datetime         not null
#  task_id                                                  :bigint           not null, indexed
#
# Indexes
#
#  index_hashcat_statuses_on_task_id  (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#
require 'rails_helper'

RSpec.describe HashcatStatus do
  describe 'associations' do
    it { is_expected.to belong_to(:task).touch(true) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:time) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:session) }
    it { is_expected.to validate_presence_of(:target) }
    it { is_expected.to validate_presence_of(:time_start) }
  end

  describe 'scopes' do
    describe '.latest' do
      let(:task) { create(:task) }
      let!(:hashcat_status_1day) { create(:hashcat_status, task: task, time: 1.day.ago) }
      let(:hashcat_status_2day) { create(:hashcat_status, task: task, time: 2.days.ago) }
      let(:hashcat_status_3day) { create(:hashcat_status, task: task, time: 3.days.ago) }

      it 'returns the latest hashcat status' do
        expect(described_class.latest).to eq(hashcat_status_1day)
      end
    end
  end

  describe 'enums' do
    let(:hashcat_status) { create(:hashcat_status) }

    it { expect(hashcat_status).to define_enum_for(:status)
                                     .with_values({ running: 3, exhausted: 5, cracked: 6, aborted: 7, quit: 8 }) }
  end

  describe 'methods' do
    describe '#status_text' do
      let(:hashcat_status) { create(:hashcat_status, status: :running) }

      it 'returns the status text' do
        expect(hashcat_status.status_text).to eq('Running')
      end
    end
  end

  describe 'factory' do
    it 'is valid' do
      expect(build(:hashcat_status)).to be_valid
    end
  end
end