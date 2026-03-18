# frozen_string_literal: true

namespace :storage do
  desc "Migrate attack resource files from Active Storage to disk-based storage"
  task migrate_from_active_storage: :environment do
    storage_base = ENV.fetch("ATTACK_RESOURCE_STORAGE_PATH",
                             Rails.root.join("storage/attack_resources").to_s)

    [WordList, RuleList, MaskList].each do |klass|
      type_dir = File.join(storage_base, klass.name.underscore.pluralize)
      FileUtils.mkdir_p(type_dir)

      klass.where(file_path: nil).find_each do |record|
        next unless record.file.attached?

        dest = File.join(type_dir, "#{record.id}-#{record.file.filename}")

        if ENV["DRY_RUN"] == "true"
          puts "[DRY RUN] Would migrate #{klass.name}##{record.id}: #{record.file.filename} → #{dest}"
          next
        end

        record.file.open do |tempfile|
          FileUtils.cp(tempfile.path, dest)
        end

        record.update!(
          file_path: dest,
          file_size: File.size(dest),
          file_name: record.file.filename.to_s
        )

        puts "Migrated #{klass.name}##{record.id}: #{record.file_name} (#{record.file_size} bytes)"
      rescue StandardError => e
        warn "ERROR migrating #{klass.name}##{record.id}: #{e.message}"
      end
    end

    puts "Migration complete."
  end

  desc "Clean up Active Storage attachments for migrated attack resources"
  task purge_migrated_attachments: :environment do
    [WordList, RuleList, MaskList].each do |klass|
      klass.where.not(file_path: nil).find_each do |record|
        next unless record.file.attached?

        if ENV["DRY_RUN"] == "true"
          puts "[DRY RUN] Would purge AS attachment for #{klass.name}##{record.id}"
          next
        end

        record.file.purge
        puts "Purged AS attachment for #{klass.name}##{record.id}"
      rescue StandardError => e
        warn "ERROR purging #{klass.name}##{record.id}: #{e.message}"
      end
    end

    puts "Purge complete."
  end
end
