#pragma once
#include <string>
#include <vector>
#include "Biquad.h"

class EqualizerAPOParser {
public:
    // Parses an Equalizer APO text file and returns a list of FilterParams.
    // Example format: Filter: ON PK Fc 1000 Hz Gain -6 dB Q 1.41
    static std::vector<FilterParams> parseFile(const std::string& filePath);
    static std::vector<FilterParams> parseContent(const std::string& content);

private:
    static FilterParams parseLine(const std::string& line);
};