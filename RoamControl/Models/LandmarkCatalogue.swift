import Foundation

/// A bundled set of widely recognised places, for choosing a test location
/// quickly without typing a search or knowing coordinates.
///
/// Coordinates point at the landmark itself rather than at its visitor centre
/// or car park, because the point of the list is to put the reported position
/// somewhere unambiguous. They are accurate to roughly the building, which is
/// far finer than any use this list is meant for.
enum LandmarkCatalogue {
    static let all: [Landmark] = europe + asia + northAmerica + southAmerica + africa + oceania

    static func grouped(matching query: String = "") -> [(region: LandmarkRegion, landmarks: [Landmark])] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = trimmed.isEmpty ? all : all.filter { $0.matches(trimmed) }

        return LandmarkRegion.allCases.compactMap { region in
            let landmarks = matches.filter { $0.region == region }
            return landmarks.isEmpty ? nil : (region, landmarks)
        }
    }

    // MARK: - Europe

    private static let europe: [Landmark] = [
        Landmark(id: "eiffel-tower", name: "Eiffel Tower", locality: "Paris, France", region: .europe, latitude: 48.8584, longitude: 2.2945, symbolName: "building.columns.fill"),
        Landmark(id: "louvre", name: "Louvre Museum", locality: "Paris, France", region: .europe, latitude: 48.8606, longitude: 2.3376, symbolName: "building.columns.fill"),
        Landmark(id: "colosseum", name: "Colosseum", locality: "Rome, Italy", region: .europe, latitude: 41.8902, longitude: 12.4922, symbolName: "building.columns.fill"),
        Landmark(id: "trevi-fountain", name: "Trevi Fountain", locality: "Rome, Italy", region: .europe, latitude: 41.9009, longitude: 12.4833, symbolName: "water.waves"),
        Landmark(id: "st-peters", name: "St Peter's Basilica", locality: "Vatican City", region: .europe, latitude: 41.9022, longitude: 12.4539, symbolName: "building.columns.fill"),
        Landmark(id: "pisa", name: "Leaning Tower of Pisa", locality: "Pisa, Italy", region: .europe, latitude: 43.7230, longitude: 10.3966, symbolName: "building.columns.fill"),
        Landmark(id: "sagrada-familia", name: "Sagrada Família", locality: "Barcelona, Spain", region: .europe, latitude: 41.4036, longitude: 2.1744, symbolName: "building.columns.fill"),
        Landmark(id: "guggenheim-bilbao", name: "Guggenheim Museum", locality: "Bilbao, Spain", region: .europe, latitude: 43.2687, longitude: -2.9340, symbolName: "building.2.fill"),
        Landmark(id: "big-ben", name: "Big Ben", locality: "London, United Kingdom", region: .europe, latitude: 51.5007, longitude: -0.1246, symbolName: "building.columns.fill"),
        Landmark(id: "tower-bridge", name: "Tower Bridge", locality: "London, United Kingdom", region: .europe, latitude: 51.5055, longitude: -0.0754, symbolName: "building.2.fill"),
        Landmark(id: "stonehenge", name: "Stonehenge", locality: "Wiltshire, United Kingdom", region: .europe, latitude: 51.1789, longitude: -1.8262, symbolName: "sparkles"),
        Landmark(id: "edinburgh-castle", name: "Edinburgh Castle", locality: "Edinburgh, United Kingdom", region: .europe, latitude: 55.9486, longitude: -3.1999, symbolName: "building.columns.fill"),
        Landmark(id: "brandenburg-gate", name: "Brandenburg Gate", locality: "Berlin, Germany", region: .europe, latitude: 52.5163, longitude: 13.3777, symbolName: "building.columns.fill"),
        Landmark(id: "neuschwanstein", name: "Neuschwanstein Castle", locality: "Bavaria, Germany", region: .europe, latitude: 47.5576, longitude: 10.7498, symbolName: "building.columns.fill"),
        Landmark(id: "anne-frank-house", name: "Anne Frank House", locality: "Amsterdam, Netherlands", region: .europe, latitude: 52.3752, longitude: 4.8840, symbolName: "building.2.fill"),
        Landmark(id: "atomium", name: "Atomium", locality: "Brussels, Belgium", region: .europe, latitude: 50.8949, longitude: 4.3415, symbolName: "sparkles"),
        Landmark(id: "charles-bridge", name: "Charles Bridge", locality: "Prague, Czechia", region: .europe, latitude: 50.0865, longitude: 14.4114, symbolName: "building.2.fill"),
        Landmark(id: "acropolis", name: "Acropolis", locality: "Athens, Greece", region: .europe, latitude: 37.9715, longitude: 23.7257, symbolName: "building.columns.fill"),
        Landmark(id: "little-mermaid", name: "The Little Mermaid", locality: "Copenhagen, Denmark", region: .europe, latitude: 55.6929, longitude: 12.5993, symbolName: "water.waves"),
        Landmark(id: "red-square", name: "Red Square", locality: "Moscow, Russia", region: .europe, latitude: 55.7539, longitude: 37.6208, symbolName: "building.columns.fill"),
        Landmark(id: "hagia-sophia", name: "Hagia Sophia", locality: "Istanbul, Türkiye", region: .europe, latitude: 41.0086, longitude: 28.9802, symbolName: "building.columns.fill")
    ]

    // MARK: - Asia

    private static let asia: [Landmark] = [
        Landmark(id: "taipei-101", name: "Taipei 101", locality: "Taipei, Taiwan", region: .asia, latitude: 25.0338, longitude: 121.5645, symbolName: "building.2.fill"),
        Landmark(id: "taroko-gorge", name: "Taroko Gorge", locality: "Hualien, Taiwan", region: .asia, latitude: 24.1583, longitude: 121.4900, symbolName: "mountain.2.fill"),
        Landmark(id: "sun-moon-lake", name: "Sun Moon Lake", locality: "Nantou, Taiwan", region: .asia, latitude: 23.8569, longitude: 120.9155, symbolName: "water.waves"),
        Landmark(id: "tokyo-tower", name: "Tokyo Tower", locality: "Tokyo, Japan", region: .asia, latitude: 35.6586, longitude: 139.7454, symbolName: "building.2.fill"),
        Landmark(id: "shibuya-crossing", name: "Shibuya Crossing", locality: "Tokyo, Japan", region: .asia, latitude: 35.6595, longitude: 139.7005, symbolName: "figure.walk"),
        Landmark(id: "mount-fuji", name: "Mount Fuji", locality: "Honshū, Japan", region: .asia, latitude: 35.3606, longitude: 138.7274, symbolName: "mountain.2.fill"),
        Landmark(id: "fushimi-inari", name: "Fushimi Inari Shrine", locality: "Kyoto, Japan", region: .asia, latitude: 34.9671, longitude: 135.7727, symbolName: "building.columns.fill"),
        Landmark(id: "great-wall", name: "Great Wall at Badaling", locality: "Beijing, China", region: .asia, latitude: 40.3587, longitude: 116.0170, symbolName: "mountain.2.fill"),
        Landmark(id: "forbidden-city", name: "Forbidden City", locality: "Beijing, China", region: .asia, latitude: 39.9163, longitude: 116.3972, symbolName: "building.columns.fill"),
        Landmark(id: "victoria-peak", name: "Victoria Peak", locality: "Hong Kong", region: .asia, latitude: 22.2759, longitude: 114.1455, symbolName: "mountain.2.fill"),
        Landmark(id: "gyeongbokgung", name: "Gyeongbokgung Palace", locality: "Seoul, South Korea", region: .asia, latitude: 37.5796, longitude: 126.9770, symbolName: "building.columns.fill"),
        Landmark(id: "marina-bay-sands", name: "Marina Bay Sands", locality: "Singapore", region: .asia, latitude: 1.2834, longitude: 103.8607, symbolName: "building.2.fill"),
        Landmark(id: "petronas-towers", name: "Petronas Towers", locality: "Kuala Lumpur, Malaysia", region: .asia, latitude: 3.1578, longitude: 101.7117, symbolName: "building.2.fill"),
        Landmark(id: "grand-palace", name: "Grand Palace", locality: "Bangkok, Thailand", region: .asia, latitude: 13.7500, longitude: 100.4913, symbolName: "building.columns.fill"),
        Landmark(id: "angkor-wat", name: "Angkor Wat", locality: "Siem Reap, Cambodia", region: .asia, latitude: 13.4125, longitude: 103.8670, symbolName: "building.columns.fill"),
        Landmark(id: "ha-long-bay", name: "Ha Long Bay", locality: "Quảng Ninh, Vietnam", region: .asia, latitude: 20.9101, longitude: 107.1839, symbolName: "water.waves"),
        Landmark(id: "borobudur", name: "Borobudur", locality: "Java, Indonesia", region: .asia, latitude: -7.6079, longitude: 110.2038, symbolName: "building.columns.fill"),
        Landmark(id: "taj-mahal", name: "Taj Mahal", locality: "Agra, India", region: .asia, latitude: 27.1751, longitude: 78.0421, symbolName: "building.columns.fill"),
        Landmark(id: "burj-khalifa", name: "Burj Khalifa", locality: "Dubai, United Arab Emirates", region: .asia, latitude: 25.1972, longitude: 55.2744, symbolName: "building.2.fill")
    ]

    // MARK: - North America

    private static let northAmerica: [Landmark] = [
        Landmark(id: "statue-of-liberty", name: "Statue of Liberty", locality: "New York, United States", region: .northAmerica, latitude: 40.6892, longitude: -74.0445, symbolName: "building.columns.fill"),
        Landmark(id: "times-square", name: "Times Square", locality: "New York, United States", region: .northAmerica, latitude: 40.7580, longitude: -73.9855, symbolName: "building.2.fill"),
        Landmark(id: "golden-gate", name: "Golden Gate Bridge", locality: "San Francisco, United States", region: .northAmerica, latitude: 37.8199, longitude: -122.4783, symbolName: "building.2.fill"),
        Landmark(id: "alcatraz", name: "Alcatraz Island", locality: "San Francisco, United States", region: .northAmerica, latitude: 37.8270, longitude: -122.4230, symbolName: "water.waves"),
        Landmark(id: "hollywood-sign", name: "Hollywood Sign", locality: "Los Angeles, United States", region: .northAmerica, latitude: 34.1341, longitude: -118.3215, symbolName: "sparkles"),
        Landmark(id: "las-vegas-strip", name: "Las Vegas Strip", locality: "Las Vegas, United States", region: .northAmerica, latitude: 36.1147, longitude: -115.1728, symbolName: "building.2.fill"),
        Landmark(id: "grand-canyon", name: "Grand Canyon South Rim", locality: "Arizona, United States", region: .northAmerica, latitude: 36.0544, longitude: -112.1401, symbolName: "mountain.2.fill"),
        Landmark(id: "space-needle", name: "Space Needle", locality: "Seattle, United States", region: .northAmerica, latitude: 47.6205, longitude: -122.3493, symbolName: "building.2.fill"),
        Landmark(id: "willis-tower", name: "Willis Tower", locality: "Chicago, United States", region: .northAmerica, latitude: 41.8789, longitude: -87.6359, symbolName: "building.2.fill"),
        Landmark(id: "white-house", name: "The White House", locality: "Washington, D.C., United States", region: .northAmerica, latitude: 38.8977, longitude: -77.0365, symbolName: "building.columns.fill"),
        Landmark(id: "walt-disney-world", name: "Walt Disney World", locality: "Florida, United States", region: .northAmerica, latitude: 28.3852, longitude: -81.5639, symbolName: "sparkles"),
        Landmark(id: "niagara-falls", name: "Niagara Falls", locality: "Ontario, Canada", region: .northAmerica, latitude: 43.0828, longitude: -79.0742, symbolName: "water.waves"),
        Landmark(id: "cn-tower", name: "CN Tower", locality: "Toronto, Canada", region: .northAmerica, latitude: 43.6426, longitude: -79.3871, symbolName: "building.2.fill"),
        Landmark(id: "chichen-itza", name: "Chichén Itzá", locality: "Yucatán, Mexico", region: .northAmerica, latitude: 20.6843, longitude: -88.5678, symbolName: "building.columns.fill")
    ]

    // MARK: - South America

    private static let southAmerica: [Landmark] = [
        Landmark(id: "christ-the-redeemer", name: "Christ the Redeemer", locality: "Rio de Janeiro, Brazil", region: .southAmerica, latitude: -22.9519, longitude: -43.2105, symbolName: "building.columns.fill"),
        Landmark(id: "machu-picchu", name: "Machu Picchu", locality: "Cusco, Peru", region: .southAmerica, latitude: -13.1631, longitude: -72.5450, symbolName: "mountain.2.fill"),
        Landmark(id: "iguazu-falls", name: "Iguazú Falls", locality: "Misiones, Argentina", region: .southAmerica, latitude: -25.6953, longitude: -54.4367, symbolName: "water.waves"),
        Landmark(id: "obelisco", name: "Obelisco de Buenos Aires", locality: "Buenos Aires, Argentina", region: .southAmerica, latitude: -34.6037, longitude: -58.3816, symbolName: "building.columns.fill"),
        Landmark(id: "salar-de-uyuni", name: "Salar de Uyuni", locality: "Potosí, Bolivia", region: .southAmerica, latitude: -20.1338, longitude: -67.4891, symbolName: "sparkles"),
        Landmark(id: "moai", name: "Easter Island Moai", locality: "Rapa Nui, Chile", region: .southAmerica, latitude: -27.1127, longitude: -109.3497, symbolName: "building.columns.fill")
    ]

    // MARK: - Africa

    private static let africa: [Landmark] = [
        Landmark(id: "pyramids-of-giza", name: "Pyramids of Giza", locality: "Giza, Egypt", region: .africa, latitude: 29.9792, longitude: 31.1342, symbolName: "building.columns.fill"),
        Landmark(id: "jemaa-el-fnaa", name: "Jemaa el-Fnaa", locality: "Marrakesh, Morocco", region: .africa, latitude: 31.6258, longitude: -7.9891, symbolName: "building.2.fill"),
        Landmark(id: "table-mountain", name: "Table Mountain", locality: "Cape Town, South Africa", region: .africa, latitude: -33.9628, longitude: 18.4098, symbolName: "mountain.2.fill"),
        Landmark(id: "victoria-falls", name: "Victoria Falls", locality: "Livingstone, Zambia", region: .africa, latitude: -17.9243, longitude: 25.8572, symbolName: "water.waves"),
        Landmark(id: "kilimanjaro", name: "Mount Kilimanjaro", locality: "Kilimanjaro, Tanzania", region: .africa, latitude: -3.0674, longitude: 37.3556, symbolName: "mountain.2.fill"),
        Landmark(id: "serengeti", name: "Serengeti National Park", locality: "Mara, Tanzania", region: .africa, latitude: -2.3333, longitude: 34.8333, symbolName: "leaf.fill")
    ]

    // MARK: - Oceania

    private static let oceania: [Landmark] = [
        Landmark(id: "sydney-opera-house", name: "Sydney Opera House", locality: "Sydney, Australia", region: .oceania, latitude: -33.8568, longitude: 151.2153, symbolName: "building.columns.fill"),
        Landmark(id: "bondi-beach", name: "Bondi Beach", locality: "Sydney, Australia", region: .oceania, latitude: -33.8908, longitude: 151.2743, symbolName: "water.waves"),
        Landmark(id: "uluru", name: "Uluru", locality: "Northern Territory, Australia", region: .oceania, latitude: -25.3444, longitude: 131.0369, symbolName: "mountain.2.fill"),
        Landmark(id: "great-barrier-reef", name: "Great Barrier Reef", locality: "Queensland, Australia", region: .oceania, latitude: -16.7000, longitude: 145.9000, symbolName: "water.waves"),
        Landmark(id: "milford-sound", name: "Milford Sound", locality: "Fiordland, New Zealand", region: .oceania, latitude: -44.6414, longitude: 167.8974, symbolName: "mountain.2.fill"),
        Landmark(id: "hobbiton", name: "Hobbiton Movie Set", locality: "Matamata, New Zealand", region: .oceania, latitude: -37.8721, longitude: 175.6820, symbolName: "leaf.fill")
    ]
}
