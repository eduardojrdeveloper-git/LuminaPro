#pragma once
#include <cmath>
#include <vector>

enum class FilterType {
    Peak,
    LowShelf,
    HighShelf,
    Preamp,
    None
};

struct FilterParams {
    FilterType type = FilterType::None;
    double fc = 1000.0;
    double gain = 0.0;
    double Q = 1.41;
};

class Biquad {
public:
    Biquad();
    void setParameters(FilterType type, double fs, double fc, double Q, double gainDB);
    float process(float input);
    void reset();

private:
    float b0, b1, b2, a1, a2;
    float z1, z2;
};
