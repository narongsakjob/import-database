module UsersImporter

  def import_users
    puts "Importing users..."
    use_old_database
    users = ActiveRecord::Base.connection.execute('
      SELECT id, email, encrypted_password, first_name, 
      last_name, current_address, tel, province_id, 
      username,  line_id, image FROM Users
    ')

    use_new_database
    users.each do |rows|
      row = OpenStruct.new(rows)
      
      if row.last_name.blank?
        name = check_blank(row.first_name)
      else
        name = row.first_name + " " + row.last_name
      end
      province = row.province_id || 1

      user = User.where(email: row.email)
      if user.blank?
        user = User.new(email: row.email, encrypted_password: row.encrypted_password,
          name: name, address: check_blank(row.current_address), phone_number: check_blank(row.tel),
          username: check_blank(row.username), province_id: province, district_id: 1,
          line_id: check_blank(row.line_id), postal_code: ""
        )

        import_image_user(row.email, row.image) unless row.image.blank?
        
        if File.exists?("#{image_path}}/#{row.email}.jpg")
          image_name = uploaded_file("lib/tasks/importer/image/#{row.email}.jpg")
        else
          puts "Users email : #{row.email} use default avatar"
          image_name = uploaded_file("app/assets/images/default_avatar.jpg")
        end
        
        image = Image.new(image: image_name, imageable_type: "User")
        image.save!
        user.avatar = image
        user.save!(validate: false)
        FileUtils.rm_rf(image_path)
      end
    end
  end

  private def check_blank(field_name)
    return "" if field_name.blank?
    return field_name
  end

  private def import_image_user(email, image)
    begin
      FileUtils::mkdir_p image_path
      puts 'Download avatar e-mail : ' + email
      Dir.chdir image_path do  
        encoded_url = URI.encode(image)
        url = URI.parse(encoded_url)
        download = open(url)
        IO.copy_stream(download, email.to_s + '.jpg') 
      end
    rescue OpenURI::HTTPError => ex
      puts "Can't download avatar e-mail : " + email
    end 
  end

  def uploaded_file(dir)
    ActionDispatch::Http::UploadedFile.new(
      tempfile: File.new(Rails.root.join(dir)),
      filename: File.basename(File.new(Rails.root.join(dir)))
    )
  end
end