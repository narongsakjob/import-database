module ProductsImporter

  require "open-uri"
  require 'fileutils'

  def import_products

    type_id_vegetable = 1, type_id_others = 3, type_id_fertilizer = 6

    puts "Importing products..."
    use_old_database
    products = ActiveRecord::Base.connection.execute('
      SELECT id, price_per_unit, unit, minimum_amount,
      user_id, title, description, listing_type_id, 
      photo_file_name FROM listings
    ')

    products.each do |rows|
      row = OpenStruct.new(rows)

      use_old_database
      old_user_data = ActiveRecord::Base.connection.execute("
        SELECT email,type_name FROM users,listing_types WHERE 
        users.id = #{row.user_id} AND listing_types.id = #{row.listing_type_id}
      ")
      old_user_data = OpenStruct.new(old_user_data.first)

      if row.listing_type_id == type_id_vegetable
        product_type = 'ผัก'
      elsif row.listing_type_id == type_id_others
        product_type = 'อื่นๆ'
      elsif row.listing_type_id == type_id_fertilizer
        product_type = 'ปุ๋ย-ยาบำรุง'
      else
        product_type = old_user_data.type_name
      end
      
      use_new_database
      new_user_data = ActiveRecord::Base.connection.execute("
        SELECT id FROM users WHERE email = '#{old_user_data.email}'
      ")
      new_user_data = OpenStruct.new(new_user_data.first)
        
      minimum_buy = row.minimum_amount || 0

      product = Product.new(name: row.title, user_id: new_user_data.id,
        product_type: product_type, details: row.description,
        minimum_buy: minimum_buy, price_per_unit: row.price_per_unit,
        unit: row.unit, fee: 0.0
      )
      product.save!(validate: false)
      
      import_product_images(row.id, row.photo_file_name) unless row.photo_file_name.blank?

      if File.exists?("#{image_path}/#{row.photo_file_name}")                      
        image_name = uploaded_file("lib/tasks/importer/image/#{row.photo_file_name}")
        image = Image.new(image: image_name, imageable_type: "Product", imageable_id: product.id, role: 1)
        image.save!
      end
      FileUtils.rm_rf(image_path)             
    end
  end

  private def import_product_images(id, photo_file_name)
    begin
      puts 'Download product image ID : ' + id.to_s
      FileUtils::mkdir_p image_path
      Dir.chdir image_path do  
        encoded_url = URI.encode("https://s3-ap-southeast-1.amazonaws.com/getkaset/listings/photos/#{get_url(id)}/large/#{photo_file_name}")
        url = URI.parse(encoded_url)
        download = open(url)
        IO.copy_stream(download, photo_file_name.to_s) 
      end
    rescue OpenURI::HTTPError => ex
      puts "Can't download product image ID : " + id.to_s
    end 
  end

  private def get_url(id)
    id_url = "%09d" % id
    id_url.to_s
    id_url.insert(3, '/')
    id_url.insert(7, '/')
    return id_url.to_s
  end   
end