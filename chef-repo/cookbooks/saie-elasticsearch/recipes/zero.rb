if node['elasticsearch']['zero']['enabled'] == false

	# We should disable things as well ... just not right now.

	return
end

user "zero" do
  uid "2009"
  home "/home/zero"
  shell '/bin/bash'
  action :create
end

group "elasticsearch" do
  members ["zero"]
  append true
  action :manage
end

directory "/home/zero" do
	owner "zero"
	group "zero"
	mode "0700"
	action :create 
end

directory "/home/zero/.ssh" do
	owner "zero"
	group "zero"
	mode "0700"
	action :create 
end

cookbook_file "/home/zero/.ssh/id_rsa" do
	source "default/zero_id_rsa"
	owner "zero"
	group "zero"
	mode "0700"
	action :create
end

template "/home/zero/request_zero.sh" do
  source "zero/request_zero.sh.erb"
  owner "zero"
  group "zero"
  mode 0555
  action :create 
end

template "/home/zero/do_zero.sh" do
  source "zero/do_zero.sh.erb"
  owner "zero"
  group "zero"
  mode 0555
  action :create 
end

cron 'request_for_zero' do
  minute '30'
  hour '21'
  weekday '*'
  user 'zero'
  mailto '""'
  home '/home/zero'
  command "/home/zero/request_zero.sh"
  action :create
end

cron 'do_zero' do
  minute '00'
  hour '22'
  weekday '*'
  user 'zero'
  mailto '""'
  home '/home/zero'
  command "/home/zero/do_zero.sh"
  action :create
end

node["elasticsearch"]["zero"]["directorys"].each do | dir |

	directory "#{dir}/zero" do
		owner "zero"
		group "zero"
		mode "0700"
		recursive true
		action :create 
	end

end

# ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no zero@stg1-av-esa05

if node["elasticsearch"]["backup_captain"] == node["fqdn"] or node["elasticsearch"]["backup_captain"] == node["hostname"]

	### There are items specific to the cluster control node ###
	# If this is the cluster control node make sure that it has the public key as its authorized key

	cookbook_file "/home/zero/.ssh/authorized_keys" do
		source "default/zero_id_rsa.pub"
		owner "zero"
		group "zero"
		mode "0700"
		action :create
	end	

	template "/home/zero/grant_zero.sh" do
		source "zero/grant_zero.sh.erb"
		owner "zero"
		group "zero"
		mode 0555
		action :create 
	end

	cron 'grant_zero' do
	  minute '00'
	  hour '22'
	  weekday '*'
	  user 'zero'
	  mailto 'ops@avention.com'
	  home '/home/zero'
	  command "/home/zero/grant_zero.sh"
	  action :create
	end

else

	### This cleans up items if this was previously a cluster control node but is not anymore ###

	file "/home/zero/.ssh/authorized_keys" do
		action :delete
	end

	file "/home/zero/zero_requests" do
		action :delete
	end	

	file "/home/zero/permission_to_zero" do
		action :delete
	end	

	file "/home/zero/grant_zero.sh" do
		action :delete
	end

	cron 'grant_zero' do
	  minute '00'
	  hour '22'
	  weekday '*'
	  user 'zero'
	  mailto 'ops@avention.com'
	  home '/home/zero'
	  command "/home/zero/grant_zero.sh"
	  action :delete
	end			

end

