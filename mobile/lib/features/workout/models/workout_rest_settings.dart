class WorkoutRestSettings {
  const WorkoutRestSettings({
    this.betweenSets = const Duration(seconds: 30),
    this.betweenExercises = const Duration(seconds: 30),
  });

  final Duration betweenSets;
  final Duration betweenExercises;
}
