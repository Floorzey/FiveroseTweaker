return function(api, boot)
	api.cache = {
		version = boot.version,
		branch = boot.branch,
		repo = boot.repo,
		dev = boot.dev,
		path = boot.root,
		fileapi = boot.fileapi
	}

	function api:source(path)
		return boot:read(path)
	end

	function api:complete(paths)
		return boot:complete(paths)
	end

	return api.cache
end
