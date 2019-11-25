# ----------------------------------------------
#            ~{ GitHub Integration }~
# [Author] Nicolò "fenix" Santilio 
# [github] fenix-hub/godot-engine.github-integration
# [version] 0.2.9
# [date] 09.13.2019





# -----------------------------------------------

tool
extends Control

onready var repo_icon = $Panel2/List/repo_infos/repo_icon
onready var private_icon = $Panel2/List/repo_infos/private_icon
onready var watch_icon = $Panel2/List/repo_infos/watch_values/watch_icon
onready var star_icon = $Panel2/List/repo_infos/star_values/star_icon
onready var fork_icon = $Panel2/List/repo_infos/fork_values/fork_icon
onready var forked_icon = $Panel2/List/repo_infos/forked_icon

onready var watch_value = $Panel2/List/repo_infos/watch_values/watch
onready var star_value = $Panel2/List/repo_infos/star_values/star
onready var fork_value = $Panel2/List/repo_infos/fork_values/fork

#onready var name_ = $Panel2/List/name
onready var html_url_ = $Panel2/List/repo_infos/html_url
onready var owner_ = $Panel2/List/repo_infos/repo_owner
onready var description_ = $Panel2/List/description
onready var default_branch_ = $Panel2/List/branch/HBoxContainer6/default_branch
onready var repo_name_ = $Panel2/List/repo_infos/repo_name
onready var contents_ = $Panel2/contents
onready var closeButton = $Panel2/close
onready var branches_ = $Panel2/List/branch/branch2
onready var DeleteRepo = $Panel2/repos_buttons/HBoxContainer2/delete
onready var Commit = $Panel2/repos_buttons/HBoxContainer3/commit
onready var DeleteRes = $Panel2/repos_buttons/HBoxContainer2/delete2

onready var reload = $Panel2/repos_buttons/HBoxContainer/reload
onready var new_branchBtn = $Panel2/List/branch/new_branchBtn
onready var newBranch = $NewBranch
onready var pull_btn = $Panel2/List/branch/pull_btn

onready var branch3 = $NewBranch/VBoxContainer/HBoxContainer2/branch3


enum REQUESTS { REPOS = 0, GISTS = 1, UP_REPOS = 2, UP_GISTS = 3, DELETE = 4, COMMIT = 5, BRANCHES = 6, CONTENTS = 7, TREES = 8, DELETE_RESOURCE = 9, END = -1 , FILE_CONTENT = 10 ,NEW_BRANCH = 11 , PULLING = 12}
var requesting

var html : String
var request = HTTPRequest.new()
var current_repo
var current_branch
var branches = []
var branches_contents = []
var contents = [] # [0] = name ; [1] = sha ; [2] = path
var dirs = []
var item_repo : TreeItem

var commit_sha = ""
var tree_sha = ""

var multi_selected = []
var gitignore_file : Dictionary


signal get_branches()
signal get_contents()
signal get_branches_contents()
signal loaded_repo()
signal resource_deleted()
signal new_branch_created()
signal zip_pulled()

func _ready():
	DeleteRes.disabled = true
	DeleteRes.connect("pressed",self,"delete_resource")
	html_url_.connect("pressed",self,"open_html")
	closeButton.connect("pressed",self,"close_tab")
	DeleteRepo.connect("pressed",self,"delete_repo")
	Commit.connect("pressed",self,"commit")
	add_child(request)
	request.connect("request_completed",self,"request_completed")
	new_branchBtn.connect("pressed",self,"on_newbranch_pressed")
	newBranch.connect("confirmed",self,"on_newbranch_confirmed")
	pull_btn.connect("pressed",self,"on_pull_pressed")

func load_icons(r):
	repo_icon.set_texture(IconLoaderGithub.load_icon_from_name("repos"))
	if r.private:
		private_icon.set_texture(IconLoaderGithub.load_icon_from_name("lock"))
	if r.fork:
		forked_icon.set_texture(IconLoaderGithub.load_icon_from_name("forks"))
	watch_icon.set_texture(IconLoaderGithub.load_icon_from_name("watch"))
	star_icon.set_texture(IconLoaderGithub.load_icon_from_name("stars"))
	fork_icon.set_texture(IconLoaderGithub.load_icon_from_name("forks"))
	reload.set_button_icon(IconLoaderGithub.load_icon_from_name("reload"))
	new_branchBtn.set_button_icon(IconLoaderGithub.load_icon_from_name("add"))
	pull_btn.set_button_icon(IconLoaderGithub.load_icon_from_name("download"))

func open_repo(repo : TreeItem):
	item_repo = repo
	
	contents_.clear()
	branches_.clear()
	branches.clear()
	contents.clear()
	
	var r = repo.get_metadata(0)
	current_repo = r
	html_url_.text = r.html_url
	owner_.text = r.owner.login
	repo_name_.text = r.name
	if r.description !=null:
		description_.text = (r.description)
	else:
		description_.text = ""
	default_branch_.text = str(r.default_branch)
	
	watch_value.set_text(str(r.watchers_count))
	star_value.set_text(str(r.stargazers_count))
	fork_value.set_text(str(r.forks_count))
	
	load_icons(r)
	
	request_branches(r.name)


func request_branches(rep : String):
	branches_.clear()
	
	requesting = REQUESTS.BRANCHES
	request.request("https://api.github.com/repos/"+UserData.USER.login+"/"+rep+"/branches",UserData.header,false,HTTPClient.METHOD_GET,"")
	yield(self,"get_branches")
	
	if branches.size() > 0:
		requesting = REQUESTS.TREES
		for b in branches:
			request.request("https://api.github.com/repos/"+UserData.USER.login+"/"+rep+"/branches/"+b.name,UserData.header,false,HTTPClient.METHOD_GET,"")
			yield(self,"get_branches_contents")
		
		var i = 0
		for branch in branches_contents:
			branches_.add_item(branch.name)
			branches_.set_item_metadata(i,branch)
			
			branch3.add_item(branch.name)
			branch3.set_item_metadata(i,branch)
			i+=1
		
		current_branch = branches_.get_item_metadata(0)
		
		request_contents(current_repo.name,branches_.get_item_metadata(0))
		yield(self,"get_contents")
		
		build_list()
	else:
		printerr(get_parent().plugin_name,"no branches found for this repository.")
		get_parent().loading(false)


func request_contents(rep : String, branch):
	contents.clear()
	contents_.clear()
	
	requesting = REQUESTS.CONTENTS
	request.request("https://api.github.com/repos/"+UserData.USER.login+"/"+rep+"/git/trees/"+branch.commit.commit.tree.sha+"?recursive=1",UserData.header,false,HTTPClient.METHOD_GET,"")

func open_html():
	get_parent().loading(true)
	OS.shell_open(html)
	get_parent().loading(false)

func close_tab():
	contents.clear()
	contents_.clear()
	branches_.clear()
	branches.clear()
	current_repo = ""
	current_branch = ""
	branches.clear()
	branches_contents.clear()
	contents.clear()
	dirs.clear()
	commit_sha = ""
	tree_sha = ""
	hide()
	get_parent().UserPanel.show()



func delete_repo():
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Do you really want to permanently delete /"+current_repo.name+" ?"
	add_child(confirm)
	confirm.rect_position = OS.get_screen_size()/2 - confirm.rect_size/2
	confirm.popup()
	confirm.connect("confirmed",self,"request_delete",[current_repo.name])

func request_delete(repo : String):
	get_parent().loading(true)
	requesting = REQUESTS.DELETE
	request.request("https://api.github.com/repos/"+UserData.USER.login+"/"+repo,UserData.header,false,HTTPClient.METHOD_DELETE,"")

func request_delete_resource(path : String, item : TreeItem = null):
	get_parent().loading(true)
	requesting = REQUESTS.DELETE_RESOURCE
	
	var body
	
	if multi_selected.size()>0:
		body = {
			"message":"",
			"sha": multi_selected[multi_selected.find(item)].get_metadata(0).sha,
			"branch":current_branch.name
			}
	else:
		body = {
			"message":"",
			"sha": contents_.get_selected().get_metadata(0).sha,
			"branch":current_branch.name
			}
	
	request.request("https://api.github.com/repos/"+UserData.USER.login+"/"+current_repo.name+"/contents/"+path,UserData.header,false,HTTPClient.METHOD_DELETE,JSON.print(body))

func commit():
	hide()
	get_parent().CommitRepo.show()
	get_parent().CommitRepo.load_branches(branches,current_repo,contents,gitignore_file)

func request_completed(result, response_code, headers, body ):
	if result == 0:
		match requesting:
			REQUESTS.DELETE:
				if response_code == 204:
					print(get_parent().plugin_name,"deleted repository...")
					OS.delay_msec(1500)
					get_parent().UserPanel.request_repositories(REQUESTS.UP_REPOS)
					close_tab()
					get_parent().loading(false)
			REQUESTS.BRANCHES:
				if response_code == 200:
					branches = JSON.parse(body.get_string_from_utf8()).result
					emit_signal("get_branches")
			REQUESTS.CONTENTS:
				if response_code == 200:
					contents = JSON.parse(body.get_string_from_utf8()).result.tree
					emit_signal("get_contents")
			REQUESTS.TREES:
				if response_code == 200:
					branches_contents.append(JSON.parse(body.get_string_from_utf8()).result)
					emit_signal("get_branches_contents")
			REQUESTS.FILE_CONTENT:
				if response_code == 200:
					gitignore_file = JSON.parse(body.get_string_from_utf8()).result
					emit_signal("get_contents")
			REQUESTS.NEW_BRANCH:
				if response_code == 201:
					print(get_parent().plugin_name,"new branch created!")
					emit_signal("new_branch_created")
					_on_reload_pressed()
				elif response_code == 422:
					printerr(get_parent().plugin_name,"ERROR: a branch with this name already exists, try choosing another name.")
					emit_signal("new_branch_created")
			REQUESTS.DELETE_RESOURCE:
				if response_code == 200:
					print(get_parent().plugin_name,"deleted selected resource")
					if multi_selected.size()>0:
						contents.remove(0)
					else:
						contents.erase(contents_.get_selected().get_metadata(0))
					emit_signal("resource_deleted")
				elif response_code == 422:
					print(get_parent().plugin_name,"can't delete a folder!")
					emit_signal("resource_deleted")
				get_parent().loading(false)
			REQUESTS.PULLING:
				if response_code == 200:
					emit_signal("zip_pulled")

func build_list():
	get_parent().loading(true)
	
	contents_.clear()
	
	var root = contents_.create_item()
	
	var directories : Array = []
	
	for content in contents:
		var content_name = content.path.get_file()
		var content_type = content.type
		if content_type == "blob":
			
			if content.path.get_file() == ".gitignore":
				request_file_content(content.path)
			else:
				gitignore_file = {}
			
			var file_dir = null
			
			for directory in directories:
				if directory.get_metadata(0) == content.path.get_base_dir():
					file_dir = directory
					continue
			
			var item = contents_.create_item(file_dir)
			item.set_text(0,content_name)
			
			var icon
			var extension = content_name.get_extension()
			if extension == "gd":
				icon = IconLoaderGithub.load_icon_from_name("script")
			elif extension == "tscn":
				icon = IconLoaderGithub.load_icon_from_name("scene")
			elif extension == "png":
				icon = IconLoaderGithub.load_icon_from_name("image")
			elif extension == "tres":
				icon = IconLoaderGithub.load_icon_from_name("resource")
			else:
				icon = IconLoaderGithub.load_icon_from_name("file")
			
			item.set_icon(0,icon)
			item.set_metadata(0,content.path.get_base_dir())
		elif content_type == "tree":
			var dir_dir = null
			
			for directory in directories:
				if directory.get_metadata(0) == content.path.get_base_dir():
					dir_dir = directory
					continue
			
			var new_dir = contents_.create_item(dir_dir)
			new_dir.set_text(0,content_name)
			new_dir.set_icon(0,IconLoaderGithub.load_icon_from_name("dir"))
			new_dir.set_metadata(0,content.path)
			directories.append(new_dir)
			
			
			new_dir.set_collapsed(true)
	
	emit_signal("loaded_repo")
	get_parent().loading(false)
	show()

func request_file_content(path : String):
	requesting = REQUESTS.FILE_CONTENT
	request.request("https://api.github.com/repos/"+UserData.USER.login+"/"+current_repo.name+"/contents/"+path,UserData.header,false,HTTPClient.METHOD_GET)
	yield(self,"get_contents")

func _on_branch2_item_selected(ID):
	get_parent().loading(true)
	current_branch = branches_.get_item_metadata(ID)
	request_contents(current_repo.name,current_branch)
	yield(self,"get_contents")
	build_list()

func delete_resource():
	if multi_selected.size()>0:
		for item in multi_selected:
			request_delete_resource(item.get_metadata(0).path,item)
			print(get_parent().plugin_name,"deleting "+item.get_metadata(0).path+"...")
			yield(self,"resource_deleted")
	else:
		request_delete_resource(contents_.get_selected().get_metadata(0).path)
		print(get_parent().plugin_name,"deleting "+contents_.get_selected().get_metadata(0).path+"...")
		yield(self,"resource_deleted")
	
	multi_selected.clear()
	
	build_list()
	DeleteRes.disabled = true

func _on_contents_item_activated():
	DeleteRes.disabled = false


func _on_contents_multi_selected(item, column, selected):
	if not multi_selected.has(item):
		multi_selected.append(item)
	else:
		multi_selected.erase(item)
	
	DeleteRes.disabled = false

func on_newbranch_pressed():
	newBranch.get_node("VBoxContainer/HBoxContainer/name").clear()
	newBranch.popup()

func on_newbranch_confirmed():
	requesting = REQUESTS.NEW_BRANCH
	
	
	if " " in newBranch.get_node("VBoxContainer/HBoxContainer/name").get_text():
		printerr(get_parent().plugin_name,"ERROR: a branch name cannot contain spaces. Please, use '-' or '_' instead.")
		return
	
	var body = {
		"ref": "refs/heads/"+newBranch.get_node("VBoxContainer/HBoxContainer/name").get_text(),
		"sha": branch3.get_item_metadata(branch3.get_selected_id()).commit.sha
	}
	
	request.request("https://api.github.com/repos/"+UserData.USER.login+"/"+current_repo.name+"/git/refs",UserData.header,false,HTTPClient.METHOD_POST,JSON.print(body))
	print(get_parent().plugin_name,"creating new branch...")
	yield(self,"new_branch_created")

func on_pull_pressed():
	requesting = REQUESTS.PULLING
	
	var zipfile = File.new()
	var zip_filepath : String = "res://"+current_repo.name+"-"+current_branch.name+".zip"
	zipfile.open_compressed(zip_filepath,File.WRITE,File.COMPRESSION_GZIP)
	zipfile.close()
	request.set_download_file(zip_filepath)
	var zip_url : String = current_branch._links.html.replace("tree","zipball").replace("github.com","api.github.com/repos")
	request.request(zip_url,UserData.header,false,HTTPClient.METHOD_GET)
	get_parent().loading(true)
	print(get_parent().plugin_name,"pulling from selected branch, a .zip file will automatically be created at the end of the process in 'res://' ...")
	yield(self,"zip_pulled")
	requesting = REQUESTS.END
	print(get_parent().plugin_name,".zip file created with the selected branch inside, you can find it at -> "+zip_filepath)
	get_parent().loading(false)
	request.set_download_file("")

func _process(delta):
	if requesting == REQUESTS.PULLING:
		if request.get_downloaded_bytes() > 0:
			get_parent().show_number(request.get_downloaded_bytes(),"bytes downloaded")

func _on_reload_pressed():
	get_parent().loading(true)
	print(get_parent().plugin_name,"reloading all branches, please wait...")
	contents.clear()
	contents_.clear()
	branches_.clear()
	branches.clear()
	current_repo = ""
	current_branch = ""
	branches.clear()
	branches_contents.clear()
	contents.clear()
	dirs.clear()
	commit_sha = ""
	tree_sha = ""
	open_repo(item_repo)
