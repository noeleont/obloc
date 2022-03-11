### A Pluto.jl notebook ###
# v0.18.1

using Markdown
using InteractiveUtils

# ╔═╡ f42eb779-f2f2-43d7-996f-97ba181399f4
begin
	using Downloads, DataFrames, CSV, TimeZones, Dates, Statistics
	using HypertextLiteral, JSONTables
end

# ╔═╡ 8b3681b9-8a63-4168-a1f1-04444b24a8bf
md"# O’BLOC 🧗‍♀️
This notebook is used to analyse scrape data of the [O'BLOC Website](https://obloc.ch). 

O'BLOC is a great climbing gym! If you are in Bern consider visiting them 😊"


# ╔═╡ 05a8266a-e30e-4e6f-bbd5-3d5c8114fca6
md"## DataFrame"

# ╔═╡ 5fa2251f-9aec-424b-b0fe-48ad15d74b7a
url = "https://raw.githubusercontent.com/ioboi/obloc-data/main/visitors.csv"

# ╔═╡ cc4c8310-5004-42fe-9cbb-0f33e7b034dd
Markdown.parse("This is the [source]($(url)) of the data.")

# ╔═╡ eb448f9c-add8-4c8f-b850-0bac4881c6f2
begin
	df = DataFrame(CSV.File(Downloads.download(url)))

	# Convert column datetime to "ZonedDateTime" and change timezone
	df.datetime = ZonedDateTime.(df.datetime, dateformat"yyyy-mm-ddTHH:MM:SS.sssz")
	df.datetime = astimezone.(df.datetime, tz"UTC+1")

	# Add columns
	df.date = Date.(df.datetime)
	df.dayofweek = Dates.dayofweek.(df.datetime)
	df.hour = Dates.hour.(df.datetime)

	# Filter out NaN entries
	df = df[.!isnan.(df.value), :]

	hourBetween(startHour::Int, endHour::Int)::BitVector = 
		df.hour .>= startHour .&& df.hour .<= endHour

	# Day filters
	mo = Dates.dayofweek.(df.datetime) .== 1
	tue = Dates.dayofweek.(df.datetime) .== 2
	wed = Dates.dayofweek.(df.datetime) .== 3
	thu = Dates.dayofweek.(df.datetime) .== 4
	fri = Dates.dayofweek.(df.datetime) .== 5
	sat = Dates.dayofweek.(df.datetime) .== 6
	sun = Dates.dayofweek.(df.datetime) .== 7

	# Actual schedules
	monTueThu = (mo .|| tue .|| thu) .&& hourBetween(10, 23)
	wedFri = (wed .|| fri) .&& hourBetween(8, 23)
	satSun = (sat .|| sun) .&& hourBetween(9, 19)

	# TODO: Respect holidays in schedule filter

	# Filter schedules
	df = df[monTueThu .|| wedFri .|| satSun, :]
end

# ╔═╡ 2f412aa6-ab67-4ff8-8bf1-5282545ea012
md"## 📊 Overview"

# ╔═╡ 24221234-bc42-4da0-a5bd-146aaa8791b8
md"### Mean Occupancy throughout the Week"

# ╔═╡ fddf3b84-98e3-4571-bf47-611db0003679
begin
	dfMeanWeeks = combine(groupby(df, :dayofweek), :value => mean)
	dfMeanWeeks.dayofweek = Dates.dayname.(dfMeanWeeks.dayofweek)
	dfMeanWeeks.value_mean = dfMeanWeeks.value_mean * 100
	rename!(dfMeanWeeks, [:dayofweek, :value_mean] .=>  ["Day of Week", "ø %Occupancy"])
end

# ╔═╡ d3631006-c877-4241-8fbb-8b6c3ba0df9d
md"### What is the best time to go climbing?"

# ╔═╡ a6666bdf-8096-4895-a46d-2b68986482fe
begin
	groupedByHour = combine(groupby(df, :hour), :value => mean, renamecols=false)
	function generateBestTimeBarChart()
		data = arraytable(groupedByHour)
		@htl("""
		<script src="https://d3js.org/d3.v6.js"></script>
		<script>
			const width = 600;
			const height = 400;
			const m = {left: 40, top: 40, right: 40, bottom: 40};

			const graphWidth = width - m.left - m.right;
			const graphHeight = height - m.top - m.bottom;
		
			const data = JSON.parse($(data));
			
			const svg = DOM.svg(width, height);

			const xScale = d3.scaleBand()
				.range([0, graphWidth])
				.domain(data.map(d => d.hour))
				.padding(0.05);

			const yScale = d3.scaleLinear()
				.range([graphHeight, 0])
				.domain([0, 1])

			d3.select(svg)
				.append("g")
				.attr("transform", `translate(\${m.left},\${m.top})`)
  				.call(d3.axisLeft(yScale));

			d3.select(svg)
				.append("g")
				.attr("transform", `translate(\${m.left},\${graphHeight+m.top})`)
  				.call(d3.axisBottom(xScale));

			d3.select(svg)
				.append("g")
				.attr("transform", `translate(\${m.left},\${m.top})`) 
				.selectAll("rect")
				.data(data, (d) => d)
				.join("rect")
	      		.attr("x", (d) => xScale(d.hour))
	      		.attr("y", (d) => yScale(d.value))
	      		.attr("width", xScale.bandwidth())
	      		.attr("height", (d) => graphHeight - yScale(d.value))
				.attr("fill", "#006446");
		
			return svg;
		</script>
		""")
	end
	generateBestTimeBarChart()
end

# ╔═╡ 52813bc0-29b9-4494-a9a2-6437da451897
begin
	function topHour()
		x = sort(groupedByHour, [:value])
		x.value = x.value * 100
		x
	end
	topHour()
end

# ╔═╡ 7b498d91-63ed-4a70-b4d4-bdcc21ceacd4
md"### Heatmap Year
This heatmap shows the mean occupancy per calendar week and day.

Sadly I started scraping in calendar week 5😢
"

# ╔═╡ 06df7a66-81d9-4673-9902-b873e3a4fe2b
begin
	# Here be Dragons!
	function generateHeatmapYear()
		data = combine(groupby(df, :date), :value=>mean, renamecols=false)
		data.week = Dates.week.(data.date)
		data.day = Dates.dayofweek.(data.date)
		data = arraytable(data)
		@htl("""
		<script src="https://d3js.org/d3.v6.js"></script>
		<script>
	
			const margins = {left: 40, top: 0, right: 20, bottom: 140};
			const data = JSON.parse($(data));
	
			const weeks = d3.range(d3.min(data.map(d=>d.week)), d3.max(data.map(d=>d.week))+1);
			const days = d3.range(1, 8);
	
			const DAYNAMES = ["Mo", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
		
			const width = 1800;
			const height = 400;
			const svg = DOM.svg(width, height);
		
			const xScale = d3.scaleBand()
	  			.range([ 0, width - margins.left - margins.right ])
				.domain(d3.range(d3.min(data.map(d=>d.week)), 53))
				.paddingInner(0.05);
	
			const yScale = d3.scaleBand()
				.range([ 0, height - margins.top - margins.bottom ])
	  			.domain(days)
				.paddingInner(0.04);
	
			const dayScale = d3.scaleBand()
				.range([ 0, height - margins.top - margins.bottom ])
	  			.domain(DAYNAMES)
				.paddingInner(0.04);
	
			const color = d3.scaleLinear()
	    	.domain([0, d3.max(data.map(d => d.value))])
	    	.range(["#e5f5e0", "#31a354"]);
	
			d3.select(svg)
	  			.append("g")
				.style("font-size", 14)
				.attr("transform", `translate(\${margins.left-0.04}, 0)`) 
	  			.call(d3.axisLeft(dayScale).tickSize(0))
				.select(".domain").remove();
	
			d3.select(svg)
	  			.append("g")
				.style("font-size", 14)
				.attr("transform", `translate(\${margins.left},\${height-margins.bottom})`) 
	  			.call(d3.axisBottom(xScale).tickSize(0))
				.select(".domain").remove();
		
			d3.select(svg)
				.append("g")
				.attr("transform", `translate(\${margins.left},\${margins.top})`) 
				.selectAll("rect")
				.data(data, (d) => d)
				.join("rect")
	      		.attr("x", (d) => xScale(d.week))
	      		.attr("y", (d) => yScale(d.day))
				.attr("rx", 4)
	      		.attr("ry", 4)
	      		.attr("width", xScale.bandwidth())
	      		.attr("height", yScale.bandwidth())
				.attr("fill", (d) => color(d.value));

			const gradient = DOM.uid();
		
			const grad = d3.select(svg)
				.append("linearGradient")
      			.attr("id", gradient.id)
      			.attr("x1", "0%")
    			.attr("y1", "0%")
    			.attr("x2", "100%")
    			.attr("y2", "0%");
		
			grad.append("stop")
					.attr("offset", "0%")
					.attr("stop-color", color(0));

			grad.append("stop")
					.attr("offset", "100%")
					.attr("stop-color", color(d3.max(data.map(d => d.value))));
		
			const legend = d3.select(svg)
				.append("g")
				.attr("transform", `translate(\${margins.left},\${height-margins.bottom + 1.5*yScale.bandwidth()})`)
				.style("font-size", 14);
		
			legend.append("text")
				.attr("x", "0")
				.attr("alignment-baseline", "middle")
				.text("Less");
		
			legend.append("rect")
				.attr("x", "30")
				.attr("y", "-10")
  				.attr("width", 100)
  				.attr("height", 20)
				.attr("fill", gradient);
		
			legend.append("text")
				.attr("x", "137")
				.attr("alignment-baseline", "middle")
				.text("More");
		
			return svg;
		</script>
		""")
	end
	generateHeatmapYear()
end

# ╔═╡ ae48bc41-89fc-4f71-bd91-2e93c9c673eb
begin
	# This cell is mainly used to display when the static html was generated.
	# It has no meaning when this notebook is used interactively. 😂
	generatedtimestap = now(tz"UTC+1")
	md"*Generated at $(generatedtimestap)*"
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
Downloads = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
JSONTables = "b9914132-a727-11e9-1322-f18e41205b0b"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
TimeZones = "f269a46b-ccf7-5d73-abea-4c690281aa53"

[compat]
CSV = "~0.10.3"
DataFrames = "~1.3.2"
HypertextLiteral = "~0.9.3"
JSONTables = "~1.0.3"
TimeZones = "~1.7.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.2"
manifest_format = "2.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "9310d9495c1eb2e4fa1955dd478660e2ecab1fbb"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.3"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "96b0bc6c52df76506efc8a441c6cf1adcb1babc4"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.42.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "ae02104e835f219b8930c7664b8012c93475c340"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.2"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3daef5523dd2e769dad2365274f760ff5f282c7d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.11"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.ExprTools]]
git-tree-sha1 = "56559bbef6ca5ea0c0818fa5c90320398a6fbf8d"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.8"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "04d13bfa8ef11720c24e4d840c0033d145537df7"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.17"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "61feba885fac3a407465726d0c330b3055df897f"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.1.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "StructTypes", "UUIDs"]
git-tree-sha1 = "8c1f668b24d999fb47baf80436194fdccec65ad2"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.9.4"

[[deps.JSONTables]]
deps = ["JSON3", "StructTypes", "Tables"]
git-tree-sha1 = "13f7485bb0b4438bb5e83e62fcadc65c5de1d1bb"
uuid = "b9914132-a727-11e9-1322-f18e41205b0b"
version = "1.0.3"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.Mocking]]
deps = ["Compat", "ExprTools"]
git-tree-sha1 = "29714d0a7a8083bba8427a4fbfb00a540c681ce7"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.7.3"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "85b5da0fa43588c75bb1ff986493443f821c70b7"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.2.3"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "db3a23166af8aebf4db5ef87ac5b00d36eb771e2"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "dfb54c4e414caa595a1f2ed759b160f5a3ddcba5"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "6a2f7d70512d205ca8c7ee31bfa9f142fe74310c"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.12"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "d24a825a95a6d98c385001212dc9020d609f2d4f"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.8.1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TimeZones]]
deps = ["Dates", "Downloads", "InlineStrings", "LazyArtifacts", "Mocking", "Printf", "RecipesBase", "Serialization", "Unicode"]
git-tree-sha1 = "2d4b6de8676b34525ac518de36006dc2e89c7e2e"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.7.2"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─f42eb779-f2f2-43d7-996f-97ba181399f4
# ╟─8b3681b9-8a63-4168-a1f1-04444b24a8bf
# ╟─05a8266a-e30e-4e6f-bbd5-3d5c8114fca6
# ╟─5fa2251f-9aec-424b-b0fe-48ad15d74b7a
# ╟─cc4c8310-5004-42fe-9cbb-0f33e7b034dd
# ╟─eb448f9c-add8-4c8f-b850-0bac4881c6f2
# ╟─2f412aa6-ab67-4ff8-8bf1-5282545ea012
# ╟─24221234-bc42-4da0-a5bd-146aaa8791b8
# ╟─fddf3b84-98e3-4571-bf47-611db0003679
# ╟─d3631006-c877-4241-8fbb-8b6c3ba0df9d
# ╟─a6666bdf-8096-4895-a46d-2b68986482fe
# ╟─52813bc0-29b9-4494-a9a2-6437da451897
# ╟─7b498d91-63ed-4a70-b4d4-bdcc21ceacd4
# ╟─06df7a66-81d9-4673-9902-b873e3a4fe2b
# ╟─ae48bc41-89fc-4f71-bd91-2e93c9c673eb
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
