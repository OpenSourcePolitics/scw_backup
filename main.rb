#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

BACKUP_RETENTION = ENV.fetch("BACKUP_RETENTION", 0)

# Listing instances
instances = `scw instance server list`.split("\n")
                                      .map { |row| row.split(/\s{2,}/o)}
                                      .drop(1)

data_output = {}

instances.each do |row| 
    data_output[row[1]] = {
                "ID" => row[0], 
                "NAME" => row[1], 
                "TYPE" => row[2], 
                "STATE" => row[3], 
                "ZONE" => row[4], 
                "PUBLIC IP" => row[5], 
                "PRIVATE IP" => row[6], 
                "TAGS" => row[7], 
                "IMAGE NAME" => row[8], 
                "MODIFICATION DATE" => row[9], 
                "CREATION DATE" => row[10], 
                "VOLUMES" => row[11], 
                "PROTECTED" => row[12], 
                "SECURITY GROUP NAME" => row[13], 
                "SECURITY GROUP ID" => row[14], 
                "STATE DETAIL" => row[15], 
                "ARCH" => row[16], 
                "IMAGE ID" => row[17]
            }
end

# Post request to create a backup
data_output.each do |instance, instance_data|
    server_id = instance_data["ID"]
    timestamp = Time.now.utc.strftime("%Y-%m-%d_%H-%M")
    server_name = instance_data["NAME"]
    backup_name = "backup_image_#{server_name}_#{timestamp}"

    header = { 'Content-Type' => 'application/json', 'X-Auth-Token' => ENV["SECRET_KEY"] }
    body = { 'action': 'backup', 'name': backup_name }

    uri = URI.parse("https://api.scaleway.com/instance/v1/zones/fr-par-1/servers/#{server_id}/action")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri, header)
    req.body = body.to_json
    response = http.request(req)
end
# End of post request

images = `scw instance image list`.split("\n")
                                  .map { |row| row.split(/\s{2,}/o)}
                                  .drop(1)

images_data_output = {}

images.each do |row| 
    images_data_output[row[1]] = {
                "ID" => row[0],
                "NAME" => row[1],
                "STATE" => row[2],
                "PUBLIC" => row[3],
                "ZONE" => row[4],
                "VOLUMES" => row[5],
                "SERVER NAME" => row[6],
                "SERVER ID" => row[7],
                "ARCH" => row[8],
                "ORGANIZATION ID" => row[9],
                "PROJECT ID" => row[10],
                "CREATION DATE" => row[11],
                "MODIFICATION DATE" => row[12]
            }
end
        
data_output.dup.each do |instance_name, instance_data|
    instance_data["IMAGES"] = images_data_output.select{ |image_name, image_data| instance_data["ID"] == image_data["SERVER ID"]}
end

snapshots = `scw instance snapshot list`.split("\n")
                                        .drop(1)
                                        .map{ |row| row.split(/\s{2,}/o)}
                                        .map{ |row| {"ID" => row[0], "NAME" => row[1]}}

data_output.each do |instance_name, instance_data|
    images_to_destroy = instance_data["IMAGES"].select{ |image_name, image_data| image_data["NAME"].start_with?("backup_image") }
    images_to_destroy = images_to_destroy.drop(BACKUP_RETENTION)

    images_to_destroy.each do |image_name, image_data| 
        image_id = image_data["ID"]
        system("scw instance image delete #{image_id}")
        snapshots_to_destroy = snapshots.select { |snapshot| snapshot["NAME"].start_with?(image_data["NAME"]) }

        snapshots_to_destroy.each do |snapshot|
            system("scw instance snapshot delete #{snapshot["ID"]}")
        end
    end 
end
