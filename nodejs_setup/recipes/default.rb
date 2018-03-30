app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

package "git" do
  options "--force-yes" if node["platform"] == "ubuntu" && node["platform_version"] == "14.04"
end

package 'unzip' do
    action :install
end

application app_path do
  javascript "4"
  environment.update("PORT" => "80")
  environment.update(app["environment"])

  remote_file app["app_source"]["url"] do
    source '/tmp/code.zip'
    mode '0755'
    action :create
  end

  bash 'extract_code_zip' do
    cwd app["app_path"]
    code 'unzip /tmp/code.zip'
  end

  # if app['type'] == 's3'
  #   windows_zipfile "#{app["app_path"]}" do
  #     source app["app_source"]["url"]
  #     action :unzip
  #     overwrite true
  #   end
  #   tar_extract app["app_source"]["url"] do
  #     target_dir app["app_path"]
  #     tar_flags [ '--strip-components 1' ]
  #     action :extract
  #   end
  # else
  #   git app_path do
  #     repository app["app_source"]["url"]
  #     revision app["app_source"]["revision"]
  #   end
  # end

  link "#{app_path}/server.js" do
    to "#{app_path}/index.js"
  end

  npm_install do
    retries 3
    retry_delay 10
  end

  npm_start do
    action [:stop, :enable, :start]
  end
end
