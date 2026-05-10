#include <stdint.h>
#include "Biquad.h"
#include "EqualizerAPOParser.h"
#include <vector>

extern "C" {
    __attribute__((visibility("default"))) __attribute__((used))
    void* dsp_create() {
        return new std::vector<Biquad>();
    }

    __attribute__((visibility("default"))) __attribute__((used))
    void dsp_destroy(void* dsp) {
        delete static_cast<std::vector<Biquad>*>(dsp);
    }

    __attribute__((visibility("default"))) __attribute__((used))
    void dsp_load_eq(void* dsp, const char* eq_content, double fs) {
        auto* filters = static_cast<std::vector<Biquad>*>(dsp);
        filters->clear();
        std::vector<FilterParams> params = EqualizerAPOParser::parseContent(eq_content);
        for (const auto& p : params) {
            Biquad bq;
            bq.setParameters(p.type, fs, p.fc, p.Q, p.gain);
            filters->push_back(bq);
        }
    }

    __attribute__((visibility("default"))) __attribute__((used))
    void dsp_process(void* dsp, float* buffer, int length) {
        auto* filters = static_cast<std::vector<Biquad>*>(dsp);
        if (filters->empty()) return;
        
        for (int i = 0; i < length; ++i) {
            float sample = buffer[i];
            for (auto& filter : *filters) {
                sample = filter.process(sample);
            }
            buffer[i] = sample;
        }
    }
}