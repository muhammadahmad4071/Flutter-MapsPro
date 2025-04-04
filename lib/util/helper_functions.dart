class HelperFunctions {
  // String _getVoiceInstruction(
  //     String distance, String maneuver, String instruction) {
  //   switch (maneuver) {
  //     case "turn-left":
  //       return "In $distance, turn left.";
  //     case "turn-right":
  //       return "In $distance, turn right.";
  //     case "straight":
  //       return "Continue straight for $distance.";
  //     case "merge":
  //       return "Merge onto the road in $distance.";
  //     case "roundabout-left":
  //       return "In $distance, take the roundabout and exit to the left.";
  //     case "roundabout-right":
  //       return "In $distance, take the roundabout and exit to the right.";
  //     default:
  //       return "In $distance, $instruction"; // Default fallback
  //   }
  // }

  String getVoiceInstruction(
      String distanceText, String maneuver, String instruction) {
    int distanceInMeters = _convertToMeters(distanceText);

    switch (maneuver) {
      case "turn-left":
        return "In $distanceInMeters meters, turn left.";
      case "turn-right":
        return "In $distanceInMeters meters, turn right.";
      case "straight":
        return "Continue straight for $distanceInMeters meters.";
      case "merge":
        return "Merge onto the road in $distanceInMeters meters.";
      case "roundabout-left":
        return "In $distanceInMeters meters, take the roundabout and exit to the left.";
      case "roundabout-right":
        return "In $distanceInMeters meters, take the roundabout and exit to the right.";
      case "uturn-left":
      case "uturn-right":
        return "In $distanceInMeters meters, make a U-turn.";
      default:
        return "In $distanceInMeters meters, ${_shortenInstruction(instruction)}";
    }
  }

  int _convertToMeters(String distanceText) {
    if (distanceText.contains("km")) {
      double kmValue = double.parse(distanceText.replaceAll(" km", ""));
      return (kmValue * 1000).round();
    } else if (distanceText.contains("m")) {
      return int.parse(distanceText.replaceAll(" m", ""));
    }
    return 0; // Fallback case
  }

  String _shortenInstruction(String instruction) {
    // Remove unnecessary phrases, you can refine this to your needs
    instruction = instruction.replaceAll(
        RegExp(r"\b(on the road|onto the|to the)\b"), '');

    // Trim the instruction to a max length (e.g., 20 words or fewer)
    List<String> words = instruction.split(" ");
    if (words.length > 5) {
      // limit to first 5 words
      words = words.sublist(0, 5);
    }

    return words.join(" ") + "..."; // Append ellipsis to indicate truncation
  }
}
