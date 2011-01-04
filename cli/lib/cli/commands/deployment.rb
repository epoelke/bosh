module Bosh::Cli::Command
  class Deployment < Base

    def show_current
      say(deployment ? "Current deployment is '#{deployment}'" : "Deployment not set")
    end

    def set_current(name)
      manifest_filename = find_deployment(name)

      if !File.exists?(manifest_filename)
        err("Missing manifest for #{name} (tried '#{manifest_filename}')")
      end
      
      manifest   = YAML.load_file(manifest_filename)
      new_target = manifest["target"]

      if !new_target
        err("Deployment manifest '#{name}' has no target, please add it before proceeding")
      end

      if target != new_target
        config.target = new_target
        say("WARNING! Your target has been changed to '#{new_target}'")
      end

      say("Deployment set to '#{manifest_filename}'")
      config.deployment = manifest_filename
      config.save
    end
    
    def perform
      err("Please log in first") unless logged_in?
      err("Please choose deployment first") unless deployment

      manifest_filename = deployment
      if !File.exists?(manifest_filename)
        err("Missing deployment at '#{deployment}'")
      end
      
      manifest = YAML.load_file(manifest_filename)      

      if manifest["name"].blank? || manifest["release"].blank? || manifest["target"].blank?
        err("Invalid manifest for '#{deployment}': name, release and target are all required")
      end

      desc = "to '#{target}' using '#{deployment}' deployment manifest"
      
      say("Deploying #{desc}...")
      say("\n")

      status, body = director.deploy(manifest_filename)

      responses = {
        :done          => "Deployed #{desc}",
        :non_trackable => "Started deployment but director at '#{target}' doesn't support deployment tracking",
        :track_timeout => "Started deployment but timed out out while tracking status",
        :error         => "Started deployment but received an error while tracking status",
        :invalid       => "Deployment is invalid, please fix it and deploy again"
      }

      say responses[status] || "Cannot deploy: #{body}"      
    end

    def delete(name)
      err("Please choose target") unless target
      err("Please log in first")  unless logged_in?

      status, message = director.delete_deployment(name)

      responses = {
        :done          => "Deleted deployment '%s'" % [ name ],
        :non_trackable => "Deployment delete in progress but director at '#{target}' doesn't support task tracking",
        :track_timeout => "Timed out out while tracking deployment deletion progress",
        :error         => "Attempted to delete deployment but received an error while tracking status",
      }

      say responses[status] || "Cannot delete deployment: #{message}"
    end

    def list
      err("Please log in first") unless logged_in?
      err("Please choose target") unless target
      deployments = director.list_deployments

      err("No deployments") if deployments.size == 0

      deployments_table = table do |t|
        t.headings = "Name"
        deployments.each do |r|
          t << [ r["name"] ]
        end
      end

      say("\n")
      say(deployments_table)
      say("\n")
      say("Deployments total: %d" % deployments.size)
    end

    private

    def find_deployment(name)
      if File.exists?(name)
        File.expand_path(name)
      else
        File.expand_path(File.join(work_dir, "deployments", "#{name}.yml"))
      end
    end
    
  end
end

