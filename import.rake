require "#{Rails.root}/lib/tasks/importer.rb"

namespace :import  do  
  desc "Import old database, usage: rails namespace:task['old_database_name']"
  task :data, [:old_database] => [:environment] do |t, args|
    Importer.import_data(args.old_database)
  end
end


