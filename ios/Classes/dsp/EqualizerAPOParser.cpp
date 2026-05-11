#include "EqualizerAPOParser.h"
#include <fstream>
#include <sstream>
#include <algorithm>

std::vector<FilterParams> EqualizerAPOParser::parseFile(const std::string& filePath) {
    std::vector<FilterParams> filters;
    std::ifstream file(filePath);
    std::string line;
    
    if (file.is_open()) {
        while (std::getline(file, line)) {
            FilterParams param = parseLine(line);
            if (param.type != FilterType::None) {
                filters.push_back(param);
            }
        }
        file.close();
    }
    return filters;
}

std::vector<FilterParams> EqualizerAPOParser::parseContent(const std::string& content) {
    std::vector<FilterParams> filters;
    std::istringstream stream(content);
    std::string line;
    
    while (std::getline(stream, line)) {
        FilterParams param = parseLine(line);
        if (param.type != FilterType::None) {
            filters.push_back(param);
        }
    }
    return filters;
}

FilterParams EqualizerAPOParser::parseLine(const std::string& line) {
    FilterParams params;
    std::string trimmed = line;
    // Trim leading whitespace
    trimmed.erase(0, trimmed.find_first_not_of(" \t"));
    
    // Check if line is a comment or empty
    if (trimmed.empty() || trimmed[0] == '#') return params;

    std::istringstream iss(trimmed);
    std::string token;
    iss >> token;

    if (token == "Preamp:") {
        iss >> params.gain;
        params.type = FilterType::Preamp; // Need to ensure Preamp is in FilterType enum
        return params;
    }

    if (token != "Filter:") return params;
    
    iss >> token; // ON/OFF
    if (token != "ON") return params;
    
    iss >> token; // Type
    if (token == "PK") params.type = FilterType::Peak;
    else if (token == "LS") params.type = FilterType::LowShelf;
    else if (token == "LSC") params.type = FilterType::LowShelf; // LSC is LS with Q
    else if (token == "HS") params.type = FilterType::HighShelf;
    else if (token == "HSC") params.type = FilterType::HighShelf;
    else return params;
    
    while (iss >> token) {
        if (token == "Fc") {
            iss >> params.fc;
        } else if (token == "Gain") {
            iss >> params.gain;
        } else if (token == "Q") {
            iss >> params.Q;
        }
        // Skip units like Hz, dB
    }
    return params;
}