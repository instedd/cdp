namespace :csv do

  desc "Start a watcher for loading all csv files on the sync folder"

  task :watch => :environment do
    sync_dir = CDXSync::SyncDirectory.new
    watcher = CDXSync::FileWatcher.new(sync_dir, logger: Rails.logger)

    Rails.logger.info "Watching directory #{sync_dir.sync_path}"

    watcher.watch do |path|
      DeviceMessageImporter.new(Settings.sync_pattern).import_single(sync_dir, path)
    end
  end
end
