class VersionValidator < ActiveModel::Validator
  def validate(record)
    unless SemVersion.valid?(record.version) && record
      record.errors[:version] << "Invalid version format"
    end
  end
end
