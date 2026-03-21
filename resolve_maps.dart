import 'package:http/http.dart' as http;

void main() async {
  final stations = [
    {
      "id": 11,
      "name": "Moon Sun Energy (North Okkalapa)",
      "map_url": "https://maps.app.goo.gl/8fRYanKjSaDpBtio9",
    },
    {
      "id": 10,
      "name": "Moon Sun Energy (Pyuntaza)",
      "map_url": "https://maps.app.goo.gl/d3dBt6mvVXUy988R8",
    },
    {
      "id": 5,
      "name": "Moon Sun Energy  (Aungpan)",
      "map_url": "https://maps.google.com/maps?q=20.6447+96.6088",
    },
    {
      "id": 1,
      "name": "Moon Sun Energy (Hlaing Tharyar-1)",
      "map_url": "https://maps.app.goo.gl/vM9VsQdR5YCt5PE98",
    },
    {
      "id": 2,
      "name": "Moon Sun Energy (Hlaing Tharyar-2)",
      "map_url": "https://maps.app.goo.gl/5WoDkLdQojLjU4wHA",
    },
    {
      "id": 7,
      "name": "Moon Sun Energy (Pyay)",
      "map_url": "https://maps.app.goo.gl/YYk7tFodE1ky92Qc6",
    },
    {
      "id": 3,
      "name": "Moon Sun Energy (Ngwe Saung)",
      "map_url": "https://maps.app.goo.gl/cyGyCngQzEkYGu1z9",
    },
    {
      "id": 8,
      "name": "Moon Sun Energy (Pantanaw)",
      "map_url": "https://maps.app.goo.gl/bjRzWsJoe7HBezNj8",
    },
    {
      "id": 12,
      "name": "Moon Sun Energy (Shwe Pyi Thar)",
      "map_url": "https://maps.app.goo.gl/Mfsoz1AFhGE7BrCAA",
    },
    {
      "id": 4,
      "name": "Moon Sun Energy (Wundwin)",
      "map_url": "https://maps.app.goo.gl/oJR96YGEXwDwqHSG7",
    },
    {
      "id": 6,
      "name": "Moon Sun Energy (Bago)",
      "map_url": "https://maps.app.goo.gl/ZyJj1CcEiMdz3Cvh6",
    },
    {
      "id": 9,
      "name": "Moon Sun Energy (Taunggyi)",
      "map_url": "https://maps.app.goo.gl/CiwY6MbAvzQpq2vWA",
    },
    {
      "id": 35,
      "name": "Moon Sun Energy (Heho)",
      "map_url": "https://maps.app.goo.gl/saYdPT2GLD69g1ba6",
    },
    {
      "id": 32,
      "name": "Moon Sun Energy (Hmawbi)",
      "map_url": "https://maps.app.goo.gl/6f6T5hvQmDHDomob9",
    },
    {
      "id": 17,
      "name": "Moon Sun Energy (Insein)",
      "map_url": "https://maps.app.goo.gl/4ePywkExSmEhikxC6",
    },
    {
      "id": 36,
      "name": "Moon Sun Energy (Yamethin)",
      "map_url": "https://maps.app.goo.gl/yNFHAbna5Xjgt7p19",
    },
    {
      "id": 30,
      "name": "Moon Sun Energy (Hopong-1)",
      "map_url": "https://maps.app.goo.gl/e8cut59aNMzdWHJr6",
    },
    {
      "id": 21,
      "name": "Moon Sun Energy (MDY-2)",
      "map_url": "https://maps.app.goo.gl/miHhnbFcSyuyPvXbA",
    },
    {
      "id": 18,
      "name": "Moon Sun Energy (Meiktila)",
      "map_url": "https://maps.app.goo.gl/gBkTxBPkyRdoia2Q9",
    },
    {
      "id": 19,
      "name": "Moon Sun Energy (Tharzi)",
      "map_url": "https://maps.app.goo.gl/H8sTjjdP7tywXxY46?g_st=av",
    },
    {
      "id": 16,
      "name": "Moon Sun Energy (Nay Pyi Taw-3)",
      "map_url": "https://maps.app.goo.gl/QZ2QBwi5fkdVviiV7",
    },
    {
      "id": 31,
      "name": "Moon Sun Energy (Myothit)",
      "map_url": "https://maps.app.goo.gl/WBqxrNpHfbRTx7Qd8",
    },
    {
      "id": 37,
      "name": "Moon Sung Energy (Pyawbwe",
      "map_url": "https://maps.app.goo.gl/SYHtUWCYUer4H9hZ9",
    },
    {
      "id": 24,
      "name": "Moon Sun Energy (MDY-5)",
      "map_url": "https://maps.app.goo.gl/MLcHWDtrurkuAxiy7?g_st=av",
    },
    {
      "id": 33,
      "name": "Moon Sun Energy (Pyin Oo Lwin)",
      "map_url": "https://maps.app.goo.gl/3NVwXUtHAF4gVm2z8",
    },
    {
      "id": 27,
      "name": "Moon Sun Energy (Pathein)",
      "map_url": "https://maps.app.goo.gl/gJCDeALFWYtyVL8EA",
    },
    {
      "id": 20,
      "name": "Moon Sun Energy (MDY-1)",
      "map_url": "https://maps.app.goo.gl/Qrsd7XvacuEtDAAk8",
    },
    {
      "id": 28,
      "name": "Moon Sun Energy (Dagon Seikkan)",
      "map_url": "https://maps.app.goo.gl/Hg1F1uN4JqQGLpys9",
    },
    {
      "id": 14,
      "name": "Moon Sun Energy (Nay Pyi Taw-1)",
      "map_url": "https://maps.app.goo.gl/gBkTxBPkyRdoia2Q9",
    },
    {
      "id": 13,
      "name": "Moon Sun Energy (South Dagon)",
      "map_url": "https://maps.app.goo.gl/q2u5mZ6Dkhvsef6T6",
    },
    {
      "id": 29,
      "name": "Moon Sun Energy (Pearl)",
      "map_url": "https://maps.app.goo.gl/d8dxoYi2DnzqiheL8",
    },
    {
      "id": 34,
      "name": "Moon Sun Energy (Gyobingauk",
      "map_url": "https://maps.app.goo.gl/M2D5Awof8aPETLio7",
    },
    {
      "id": 15,
      "name": "Moon Sun Energy (Nay Pyi Taw-2)",
      "map_url": "https://maps.app.goo.gl/v7SpA2w4qmJbiiWa9",
    },
    {
      "id": 26,
      "name": "Moon Sun Energy (Sint Gaing)",
      "map_url": "https://maps.app.goo.gl/bMuuun5gdzqZspwe7",
    },
    {
      "id": 25,
      "name": "Moon Sun Energy (Thahton)",
      "map_url": "https://maps.app.goo.gl/yoTtw2nfa3N6aYnG7",
    },
    {
      "id": 23,
      "name": "Moon Sun Energy (MDY-4)",
      "map_url": "https://maps.app.goo.gl/QZ2QBwi5fkdVviiV7",
    },
  ];

  for (var station in stations) {
    final url = station['map_url'] as String;
    final id = station['id'];

    try {
      if (url.contains('maps?q=')) {
        final coordsStr = url.split('maps?q=').last;
        final parts = coordsStr.split('+');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0]);
          final lng = double.tryParse(parts[1]);
          if (lat != null && lng != null) {
            print('UPDATE stations SET lat = $lat, lng = $lng WHERE id = $id;');
          }
          continue;
        }
      }

      final client = http.Client();
      var currentUrl = url;
      String? finalLocation;

      // Follow up to 3 redirects to find a URL with coordinates
      for (var i = 0; i < 3; i++) {
        final request = http.Request('GET', Uri.parse(currentUrl))
          ..followRedirects = false;
        final response = await client.send(request);
        finalLocation = response.headers['location'];
        if (finalLocation == null) break;

        if (finalLocation.contains('@')) break;
        if (finalLocation.contains('query=')) break;

        currentUrl = finalLocation;
        if (!currentUrl.startsWith('http')) {
          // Handle relative redirects if any
          currentUrl = Uri.parse(url).resolve(currentUrl).toString();
        }
      }

      if (finalLocation != null) {
        final regExp = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
        var match = regExp.firstMatch(finalLocation);
        if (match != null) {
          print(
            'UPDATE stations SET lat = ${match.group(1)}, lng = ${match.group(2)} WHERE id = $id;',
          );
        } else {
          final qMatch = RegExp(
            r'query=(-?\d+\.\d+)(?:%2C|,)(-?\d+\.\d+)',
          ).firstMatch(finalLocation);
          if (qMatch != null) {
            print(
              'UPDATE stations SET lat = ${qMatch.group(1)}, lng = ${qMatch.group(2)} WHERE id = $id;',
            );
          }
        }
      }
      client.close();
    } catch (e) {
      // ignore
    }
  }
}
