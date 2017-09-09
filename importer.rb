require File.dirname(__FILE__) +  "/importer/users_importer"
require File.dirname(__FILE__) +  "/importer/products_importer"

class Importer

  include UsersImporter, ProductsImporter
  attr_accessor :new_database_name, :old_database_name, :image_path

  def initialize new_database_name, old_database_name

    puts "Importing from #{old_database_name} to #{new_database_name}"

    self.new_database_name = new_database_name
    self.old_database_name = old_database_name
    self.image_path = "#{Rails.root}/lib/tasks/importer/image"
  end

  def import_database
    import_users
    import_products
  end

  def use_new_database
    ActiveRecord::Base.establish_connection(
      adapter:    "postgresql",
      database:   "#{new_database_name}"
    )
  end

  def use_old_database
    ActiveRecord::Base.establish_connection(
      adapter:    "postgresql",
      database:   "#{old_database_name}"
    )
  end

  def self.import_data(old_database_name)
    new_database_name = YAML::load(IO.read(Rails.root.join("config/database.yml")))[Rails.env]["database"]
    puts "old_database : " + old_database_name
    puts "new_database : " + new_database_name
    importer = Importer.new new_database_name, old_database_name
    importer.import_database
  end
end