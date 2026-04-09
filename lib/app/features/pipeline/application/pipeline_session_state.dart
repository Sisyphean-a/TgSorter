enum NextAvailability { cached, fetchable, none }

class NavigationAvailability {
  const NavigationAvailability({
    required this.canShowPrevious,
    required this.next,
  });

  final bool canShowPrevious;
  final NextAvailability next;

  bool get canShowNext => next != NextAvailability.none;
}
