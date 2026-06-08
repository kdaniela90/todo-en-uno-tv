class Movie {
  final String id;
  final String name;
  final String streamIcon;
  final String categoryId;
  final String containerExtension;
  final String plot;
  final String cast;
  final String genre;
  final String releaseDate;
  final String rating;

  Movie({
    required this.id,
    required this.name,
    required this.streamIcon,
    required this.categoryId,
    required this.containerExtension,
    required this.plot,
    required this.cast,
    required this.genre,
    required this.releaseDate,
    required this.rating,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    final info = json['movie_data'] ?? json;
    return Movie(
      id: json['stream_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      streamIcon: json['stream_icon']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      containerExtension: json['container_extension']?.toString() ?? 'mp4',
      plot: info['plot']?.toString() ?? '',
      cast: info['cast']?.toString() ?? '',
      genre: info['genre']?.toString() ?? '',
      releaseDate: info['releaseDate']?.toString() ?? '',
      rating: info['rating']?.toString() ?? '',
    );
  }

  String streamUrl(String baseUrl, String username, String password) {
    return '$baseUrl/movie/$username/$password/$id.$containerExtension';
  }
}
