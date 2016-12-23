// 6Harmonics Qige
// Microsoft Bing Maps API v7
// 2016.12.23: + jQuery, add jQuery functions, add "#sidebar"

var _appVersion = 'Field (Microsoft Bing Maps) v6.1.211216';
var _appLat = 40.0492, _appLng = 116.2902;
var _page = 'bing.html', _file = '', _type = 1;
var _bingMap = null, _mapConfig = null;

(function($) {
	$.url = {
		get: function(key) {
			var reg = new RegExp("(^|&)" + key + "=([^&]*)(&|$)");
			var r = window.location.search.substr(1).match(reg);
			if (r != null) return unescape(r[2]); return null;
		},
		goto: function(url) {
			$(window.location).attr('href', url);
		}
	};
}) (jQuery);

(function($) {
	$.app = {
		init: function() {
			$('#thrpt').attr('href', _page + '?f=' + _file + '&t=1');
			$('#snr').attr('href', _page + '?f=' + _file + '&t=2');
			$('#noise').attr('href', _page + '?f=' + _file + '&t=3');
			$('#per').attr('href', _page + '?f=' + _file + '&t=4');
			$('#legend').attr('src', 'res/legend-' + _type + '.png');
			$('#file').val(_file);

			$('#btn-sidebar-sw').click(function() {
				$('#sidebar').fadeToggle();
			});
			$('#file').keydown(function(event) {
				if (event.which == 13) {
					$.url.goto(_page + '?f=' + $('#file').val() + '&t=' + _type);
				}
			});
			$('#reload').click(function() {
				$.url.goto(_page + '?f=' + $('#file').val() + '&t=' + _type);
			});
			$('#home').click(function() {
				$.url.goto('index.html');
			});
			$('#log-file-form').submit(function() {
				console.log('-- check file first');
				if ($('#log-file').val() == '') return false;
			});
		},
		sync: function(resp) { //console.dir(resp);
			if (typeof(resp) != 'undefined' && resp 
					&& typeof(resp.dev) != 'undefined'
						&& typeof(resp.data) != 'undefined') 
			{
				$('#dev').val(resp.dev.mac);
				$('#peer').val(resp.dev.peer);
				
				$('#ptotal').val(resp.data.pstat.total);
				$('#pstrong').val(resp.data.pstat.strong);
				$('#pnormal').val(resp.data.pstat.normal);
				$('#pweak').val(resp.data.pstat.weak);
				$('#pbad').val(resp.data.pstat.bad);
			}
		},
		error: function(msg) {
			$('#dev').val(msg);
			$('#peer').val(msg);
		}
	};
}) (jQuery);

// TODO: add Pushpin at every point (with icon), add Infobox when clicked.
(function($) {
	$.MicrosoftMap = {
		init: function(obj, center, dbg) {
			//console.log('$.MicrosoftMap.init()');
			return new Microsoft.Maps.Map(obj, {
				center: _mapConfig.center, zoom: _mapConfig.zoomLevel,
				credentials: dbg ? 'AhnlfvF1xVTU6hqJs2ueQB7f46mv4JkkkdbqYQ3sPUkYu7CjonMpC8WVFVvG7mMX'
						: 'ApI17LQorAgXC64mQ85EC-ZJlcxUn0pthYc0klwLxi8EzFC0lhnrQEutHj8o3CEL', 
				showMapTypeSelector: false, showBreadcrumb: true, enableClickableLogo: false,
				enableSearchLogo: false, mapTypeId: Microsoft.Maps.MapTypeId.aerial
			});
		},
		sync: function(bMap, data) {
			console.log('$.MicrosoftMap.sync()');
			//console.dir(data);
			if ($.isArray(data)) {
				console.log('$.MicrosoftMap.icons(): update');
				console.dir(data);
				bMap.entities.clear();
				
				var idx = 0;
				for(idx in data) {
					var pos = new this.pos(data[idx].lat, data[idx].lng);
					var pin = new this.pushpin(pos, 'res/icon-' + data[idx].level + '.png');
					//Microsoft.Maps.Events.addHandler(pin, 'click', this.showInfobox);
					bMap.entities.push(pin);
				}
			} else {
				//console.log('$.MicrosoftMap.icons(): default');
				var dev = this.infobox(bMap.getCenter(), 'Designed by 6WiLink Qige', 
						'Address: Suit 3B-1102/1105, Z-Park, Haidian Dist., Beijing, China', true);
				bMap.entities.push(dev);
			}
		},
		showInfobox: function(e) {
			console.dir(e);
		},
		// FIXME: pass event & params at same time
		infobox: function(center, title, msg, visible) {
			return (new Microsoft.Maps.Infobox(center, { 
				title: title, description: msg, visible: visible, width: 360, height: 90
			}));
		},
		pushpin: function(center, icon) {
			return (new Microsoft.Maps.Pushpin(center, { 
				icon: icon, width: 19, height: 25
			}));
		},
		setView: function(bMap, view) {
			bMap.setView(view);
		},
		pos: function(lat,lng) {
			return (new Microsoft.Maps.Location(lat, lng));
		}
	};
}) (jQuery);

// start
$(document).ready(function() {
	// init basic values
	console.log(_appVersion);
	_file = $.url.get('f');
	_type = $.url.get('t');
	
	if (! _file) _file = 'demo.log';
	if (! _type) _type = 1;
	$.app.init(_file, _type);
	
	// default settings
	_mapConfig = {
		center: $.MicrosoftMap.pos(_appLat,_appLng),
		zoomLevel: 16, points: null, msg: null
	};
  
  //console.log('add Microsoft.Maps first');
	// init Microsoft Bing Maps
	_bingMap = $.MicrosoftMap.init($('#map')[0], _mapConfig.center, debug = true); 

	// fetch data & add points (icon)
	//console.log('parse file into array: '+_file);
	$.get('data/data.php', { f: _file, t: _type }, function(resp) { //console.dir(resp);
		if (typeof(resp.dev) != 'undefined' && typeof(resp.data) != 'undefined') {
			$.app.sync(resp); //console.log('- ajax json data fetched & valid');
		}
		if (typeof(resp.map) != 'undefined' && typeof(resp.map.center) != 'undefined') {
			_mapConfig.zoomLevel = resp.map.zoom; //console.log('-- update map');
			if (_mapConfig.center) {
				delete(_mapConfig.center); //console.log('- release old center');
			}
			_mapConfig.center = $.MicrosoftMap.pos(resp.map.center.lat, resp.map.center.lng);
			_mapConfig.points = resp.data.points;
			_mapConfig.msg = resp.data.msg;
		} else {
			console.log('invalid data');
			$.app.error('File Format Invalid');	
		}
		
    // clear & add new icons
		$.MicrosoftMap.sync(_bingMap, _mapConfig.points); 
    // move & zoom
		$.MicrosoftMap.setView(_bingMap, { center: _mapConfig.center, zoom: _mapConfig.zoomLevel });
	},'json');
});
