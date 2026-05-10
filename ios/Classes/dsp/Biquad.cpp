#include "Biquad.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

Biquad::Biquad() : b0(1.0f), b1(0.0f), b2(0.0f), a1(0.0f), a2(0.0f), z1(0.0f), z2(0.0f) {}

void Biquad::reset() {
    z1 = 0.0f;
    z2 = 0.0f;
}

void Biquad::setParameters(FilterType type, double fs, double fc, double Q, double gainDB) {
    double w0 = 2.0 * M_PI * fc / fs;
    double alpha = sin(w0) / (2.0 * Q);
    double A = pow(10.0, gainDB / 40.0);

    double a0 = 1.0;
    double b0_t = 1.0, b1_t = 0.0, b2_t = 0.0, a0_t = 1.0, a1_t = 0.0, a2_t = 0.0;

    switch (type) {
        case FilterType::Peak:
            b0_t = 1.0 + alpha * A;
            b1_t = -2.0 * cos(w0);
            b2_t = 1.0 - alpha * A;
            a0_t = 1.0 + alpha / A;
            a1_t = -2.0 * cos(w0);
            a2_t = 1.0 - alpha / A;
            break;
        case FilterType::LowShelf:
            b0_t = A * ((A + 1.0) - (A - 1.0) * cos(w0) + 2.0 * sqrt(A) * alpha);
            b1_t = 2.0 * A * ((A - 1.0) - (A + 1.0) * cos(w0));
            b2_t = A * ((A + 1.0) - (A - 1.0) * cos(w0) - 2.0 * sqrt(A) * alpha);
            a0_t = (A + 1.0) + (A - 1.0) * cos(w0) + 2.0 * sqrt(A) * alpha;
            a1_t = -2.0 * ((A - 1.0) + (A + 1.0) * cos(w0));
            a2_t = (A + 1.0) + (A - 1.0) * cos(w0) - 2.0 * sqrt(A) * alpha;
            break;
        case FilterType::HighShelf:
            b0_t = A * ((A + 1.0) + (A - 1.0) * cos(w0) + 2.0 * sqrt(A) * alpha);
            b1_t = -2.0 * A * ((A - 1.0) + (A + 1.0) * cos(w0));
            b2_t = A * ((A + 1.0) + (A - 1.0) * cos(w0) - 2.0 * sqrt(A) * alpha);
            a0_t = (A + 1.0) - (A - 1.0) * cos(w0) + 2.0 * sqrt(A) * alpha;
            a1_t = 2.0 * ((A - 1.0) - (A + 1.0) * cos(w0));
            a2_t = (A + 1.0) - (A - 1.0) * cos(w0) - 2.0 * sqrt(A) * alpha;
            break;
        default:
            break;
    }

    b0 = static_cast<float>(b0_t / a0_t);
    b1 = static_cast<float>(b1_t / a0_t);
    b2 = static_cast<float>(b2_t / a0_t);
    a1 = static_cast<float>(a1_t / a0_t);
    a2 = static_cast<float>(a2_t / a0_t);
}

// Transposed Direct Form II
float Biquad::process(float input) {
    float output = input * b0 + z1;
    z1 = input * b1 + z2 - a1 * output;
    z2 = input * b2 - a2 * output;
    return output;
}