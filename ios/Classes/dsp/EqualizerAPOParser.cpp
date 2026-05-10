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
    std::istringstream iss(line);
    std::string token;
    
    iss >> token;
    if (token != "Filter:") return params;
    
    iss >> token; // ON/OFF
    if (token != "ON") return params;
    
    iss >> token; // Type
    if (token == "PK") params.type = FilterType::Peak;
    else if (token == "LS") params.type = FilterType::LowShelf;
    else if (token == "HS") params.type = FilterType::HighShelf;
    else return params; // Unsupported filter
    
    while (iss >> token) {
        if (token == "Fc") {
            iss >> params.fc;
            iss >> token; // Hz
        } else if (token == "Gain") {
            iss >> params.gain;
            iss >> token; // dB
        } else if (token == "Q") {
            iss >> params.Q;
        }
    }
    return params;
}