require 'pp'
require 'json'
require 'open-uri'
$key = IO.read('key.txt')

def get_page(url)
  contents = nil
  open(url) { |f| contents = f.read } 

  return contents
end

#get the page
page = get_page('http://www.webpass.net/buildings?city=san+francisco').gsub("\n", '')

#strip out tags, html entities, etc from html table
table = page.match(/<table.*<\/table>/)[0].gsub(/&#[0-9]+;|<\/[a-z]+>|<[a-z]+.*?>|&nbsp;.*?;/,"\n").split(/\n+/).drop(4).map do |line|
  if line.include?('Residential')
    #sort into residential and commercial
    'Residential'
  elsif line.include?('Commercial')
    'Commercial'
  else
    line
  end
end

fixed = []

#we want lines to be in the form of 
#[address, commercial/residential]
#however, some rows have 2 residential entries
#so we want to collapse 2 consecutive residential 
table.each do |e|
  next if(e == fixed.last)
  fixed.push(e)
end

#we don't care about residential entries
buildings = fixed.each_slice(2).to_a.keep_if { |x| x[1].include?('Residential') }.each { |x| x[0] += ', San Francisco, California' } 

def getCoordinates(address)
  path = "coords/#{address.gsub(/[^0-9A-Za-z]/,'')}"
  if(File.exist?(path))
    coords = IO.read(path)
    results = JSON.parse(coords)
    if(results['status'] == 'OK')
      addr = results['results'][0]['formatted_address']
      geometry = results['results'][0]['geometry']['location']
      return [addr, geometry]
    end
  end

  base_url = 'http://maps.googleapis.com/maps/api/geocode/json?'
  params = { :sensor => 'false', :address => address}.to_a.map { |x| x[0].to_s + "=" + x[1].to_s }.join("&") 

  full_url = base_url + params.gsub(' ', '%20')
  results = nil
  open(full_url) { |x| results = x.read } 

  File.open(path, 'w+') { |f| f.puts(results) } if results
end

def writePage(page)
  i = -1
  strings = ['var lastOpened;']
  strings += page.map do |e|
    i+=1
    %{var marker#{i} = new google.maps.Marker({ 
        position: new google.maps.LatLng(#{e[1]['lat']}, #{e[1]['lng']}),
        map: map,
        title: '#{e[0]}'});

      var infoWindow#{i} = new google.maps.InfoWindow( {
                              content: '#{e[0]}'
                            });

      google.maps.event.addListener(marker#{i}, 'click', function() {
        if(lastOpened) {
          lastOpened.close();
        }
        infoWindow#{i}.open(map, marker#{i});
        lastOpened = infoWindow#{i};
      });
    }
  end

%{<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
    <style type="text/css">
      html { height: 100% }
      body { height: 100%; margin: 0; padding: 0 }
      #map_canvas { height: 100% }
    </style>
    <script type="text/javascript"

      src="https://maps.googleapis.com/maps/api/js?v=3.exp&key=#{$key}&sensor=false">
    </script>
    <script type="text/javascript">
      function initialize() {
        var mapOptions = {
          center: new google.maps.LatLng(37.7750, -122.4183),
          zoom: 12,
          mapTypeId: google.maps.MapTypeId.ROADMAP
        };
        var map = new google.maps.Map(document.getElementById("map_canvas"),
            mapOptions);
        #{strings.join("\n")}
        
      }
    </script>
  </head>
  <body onload="initialize()">
     <div id="map_canvas" style="width:100%; height:100%"></div> 
  </body>
  %}
end

coords = buildings.map { |x| getCoordinates(x[0]) }
puts writePage(coords)


