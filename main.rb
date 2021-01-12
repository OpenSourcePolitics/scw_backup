#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# Number of backup we want to keep for each instance
BACKUP_RETENTION = ENV.fetch("BACKUP_RETENTION", 1)


def verbose?
    ENV.fetch("VERBOSE", false)
end


# Listing component
def list(component)
    `scw instance #{component} list`.split("\n")
                                    .map { |row| row.split(/\s{2,}/o)}
                                    .drop(1)
end


def list_images
    images = list("image")
    pp images if verbose?
    images
end


def list_servers
    instances = list("server") 
    pp instances if verbose?
    instances   
end


def list_snapshots
    # Listing snapshots
    snapshots = list("snapshot").map{ |row| {"ID" => row[0], "NAME" => row[1]}}
    pp snapshots if verbose?
    snapshots
end


def create_backup!(server_id:, server_name:)
    # Init vars
    timestamp = Time.now.utc.strftime("%Y-%m-%d_%H-%M")
    backup_name = "backup_image_#{server_name}_#{timestamp}"

    # Header and body content for the request
    header = { 'Content-Type' => 'application/json', 'X-Auth-Token' => ENV["SECRET_KEY"] }
    body = { 'action': 'backup', 'name': backup_name }

    # Building request
    uri = URI.parse("https://api.scaleway.com/instance/v1/zones/fr-par-1/servers/#{server_id}/action")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri, header)
    req.body = body.to_json

    # Execute request and send response 
    response = http.request(req)

    pp "Backup name : #{backup_name}" if verbose?
    pp "HTTP Response Request : #{response.body}" if verbose?
end


def get_snapshot_ids_for(image_data, snapshots:)
    snapshots.select { |snapshot| snapshot["NAME"].start_with?(image_data["NAME"]) }
             .map { |snapshot| snapshot["ID"]}
end


def delete_image!(image_data)
    system("scw instance image delete #{image_data["ID"]}")
    pp "Image #{image_data["NAME"]} has been deleted" if verbose?
end


def delete_snapshots!(snapshots_to_destroy)
    snapshots_to_destroy.each do |id|
        system("scw instance snapshot delete #{id}")
        pp "Snapshot_id #{id} has been deleted" if verbose?
    end
end


def delete_images_and_snapshots!(images_to_destroy)
    # For each image in images_to_destroy array, run scw command to delete the image
    images_to_destroy.each do |image_name, image_data| 
        delete_image!(image_data)

        # Also delete each snapshot linked to destroyed image
        snapshots_ids = get_snapshot_ids_for(image_data, snapshots: list_snapshots)
        delete_snapshots!(snapshots_ids)
    end 
end


# Init hash with listed instances and data for each instance
instances_data_output = {}

list_servers.each do |row|
    instances_data_output.store(row[1], {
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
    })
end

# Post request to create a backup for each instance
instances_data_output.each do |instance, instance_data|
    create_backup!(server_id: instance_data["ID"], server_name: instance_data["NAME"])
end
# End of post request

# Init hash with listed images and data for each image
images_data_output = {} 

list_images.each do |row|
    images_data_output.store(row[1],  {
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
    })
end
 
# Add existing images for each instance in listed instances hash
instances_data_output.dup.each do |instance_name, instance_data|
    instance_data["IMAGES"] = images_data_output.select{ |image_name, image_data| instance_data["ID"] == image_data["SERVER ID"]}
end

# List all images for each instance and exclude the last backup images according to the backup retention number
instances_data_output.each do |instance_name, instance_data|
    images_to_destroy = instance_data["IMAGES"].select{ |image_name, image_data| image_data["NAME"].start_with?("backup_image") }
    images_to_destroy = images_to_destroy.drop(BACKUP_RETENTION)

    delete_images_and_snapshots!(images_to_destroy)
end
