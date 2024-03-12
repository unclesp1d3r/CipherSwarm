# == Schema Information
#
# Table name: operating_systems
#
#  id                                                     :bigint           not null, primary key
#  cracker_command(Command to run the cracker on this OS) :string
#  name(Name of the operating system)                     :string           indexed
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#
# Indexes
#
#  index_operating_systems_on_name  (name) UNIQUE
#
FactoryBot.define do
  factory :windows, :operating_system do
    name { "windows" }
    cracker_command { "hashcat.exe" }
  end

  factory :linux, class: OperatingSystem do
    name { "linux" }
    cracker_command { "hashcat.bin" }
  end

  factory :darwin, class: OperatingSystem do
    name { "darwin" }
    cracker_command { "hashcat.bin" }
  end
end
