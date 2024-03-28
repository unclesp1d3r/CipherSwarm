class VersionValidator < ActiveModel::Validator
  def validate(record)
    if record.nil? || record.version.nil? || record.version.empty?
      record.errors[:version] << "Version can't be blank"
      return
    end
    unless record.present? && SemVersion.valid?(record.version)
      record.errors[:version] << "Invalid version format"
    end
  end
end
