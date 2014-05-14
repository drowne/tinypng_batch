# requirements
fs = require("fs")
path = require("path")
walk = require("walk")
http = require("http")
https = require("https")
url = require("url")

# configurables
apiKey = "INSERT_API_KEY_HERE"
images_dir = "images"

# variables
size_profit = 0

is_a_png_file = (filename) ->
	return filename.toLowerCase().match(/.png$/)

magical_compression = (image, cb) ->
	file = fs.readFileSync(image)

	if not file
		console.error("error reading #{image}")
		return;

	console.log("compressing #{image}")
	
	post_options = {
		hostname: "api.tinypng.com"
		host: "api.tinypng.com"
		port: "443"
		path: "/shrink"
		method: "POST"
		headers: {
			"Authorization": "Basic " + new Buffer("api:#{apiKey}").toString("base64")
			"Content-Type": "image/png"
			"Referer": "https://tinypng.org/"
			"Content-Length": file.length
			"Cache-Control": "no-cache"
			"Pragma": "no-cache"
			"Origin": "https://tinypng.org"
		}
		rejectUnauthorized: false
		requestCert: false
		agent: false
	}
	
	req = https.request(post_options, (res) ->
		res.setEncoding("utf8")

		response = ""
		res.on("data", (chunk) ->
			response += chunk
		)

		res.on("end", (end_response) ->
			response = JSON.parse(response)
			
			if response.code or response.message
				console.error("error: #{response.message}")
				return;
			else

				size_profit += response.input.size - response.output.size

				img_data = ""
				https.get(response.output.url, (get_res) ->
					get_res.setEncoding("binary")
					get_res.on("data", (chunk) ->
						img_data += chunk;
					)

					get_res.on("end", () ->
						fs.writeFileSync(image, img_data, 'binary')
						compressed_images.push(image)
						cb and cb()
					)
				)
		)
	)

	req.write(file)
	req.end()

compressed_images = []
compressed_images = JSON.parse(fs.readFileSync("./compressed_images.log")) if fs.existsSync("./compressed_images.log")

compress_images = (images) ->
	
	image = images.pop()

	if not image
		fs.writeFileSync("compressed_images.log", JSON.stringify(compressed_images), "utf-8")
		console.log("Kb saved with tinypng compression: #{Math.round(size_profit/1000)}")
		return;

	if compressed_images.indexOf(image) isnt -1
		console.warn("skipping this file (already compressed) #{image}")
		compress_images(images)
		return;

	if image.match("_compressed.png") or not is_a_png_file(image)
		console.warn("skipping this file (not a png file or filename ends with _compressed) #{image}")
		compress_images(images)
		return;
	
	magical_compression(image, (error) ->
		if not error
			fs.writeFileSync("compressed_images.log", JSON.stringify(compressed_images), "utf-8")
		
		setTimeout(() ->
			compress_images(images)
		, 500)
	)

console.log("trying this path: "+ images_dir)
console.log("initializing...")

images_array = []
options = {
	listeners: {
		names: (root, nodeNamesArray) ->
			nodeNamesArray.sort((a, b) ->
				return 1  if a > b
				return -1  if a < b
				return 0
			)

		directories: (root, dirStatsArray, next) ->
			# dirStatsArray is an array of `stat` objects with the additional attributes
			# * type
			# * error
			# * name
			next()

		file: (root, fileStats, next) ->

			pathtofile = if fileStats.name.substring(0, 1) == '/' then fileStats.name.substring(1) else fileStats.name
			pathtofile = "#{root}/#{pathtofile}"

			console.log "trying to read #{pathtofile}"

			filename = fileStats.name
			if is_a_png_file(filename)
				data = fs.readFileSync("#{pathtofile}")
				if data
					# images_array.push(data)
					images_array.push("#{pathtofile}")
					console.log "#{pathtofile} added"
				else
					console.log "error"

			next()

		errors: (root, nodeStatsArray, next) ->
			next()

		end: () ->
			compress_images(images_array)
	}

}

walker = walk.walkSync(images_dir, options)
