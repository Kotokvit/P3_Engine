#pragma once

#include <cmath>
#include <cstdint>
#include <iostream>

namespace P3Engine {
namespace Math {

struct Vector4P {
    double X{0.0};
    double Y{0.0};
    double Z{0.0};
    double W{1.0};

    Vector4P Normalize() const {
        double norm = std::sqrt(X*X + Y*Y + Z*Z + W*W);
        if (norm == 0.0) return {0,0,0,0};
        return {X / norm, Y / norm, Z / norm, W / norm};
    }
};

struct GeodeticPoint {
    double LatitudeDeg{0.0};
    double LongitudeDeg{0.0};
    double ElevationMeters{0.0};
};

enum EMetricQuadrant : uint8_t {
    Quadrant_I   = 0,
    Quadrant_II  = 1,
    Quadrant_III = 2,
    Quadrant_IV  = 3,
    Undefined    = 255
};

struct ProjectiveConstants {
    static constexpr double DELTA_LAT_DEG = 0.6533;
    static constexpr double DELTA_LON_DEG = 4.1567;
    static constexpr double AFFINE_SCALE_W = 0.871985;
    static constexpr double REFERENCE_GEOID_RADIUS_M = 5838400.0;
    static constexpr double FUNDAMENTAL_NYQUIST_HZ = 18.7;
    static constexpr double CAVITY_RESONANCE_HZ = 432.0;
};

class TopologyConjugator {
public:
    static GeodeticPoint TransformGeodetic(const GeodeticPoint& SourcePoint) {
        GeodeticPoint TargetPoint;
        TargetPoint.LatitudeDeg = SourcePoint.LatitudeDeg + ProjectiveConstants::DELTA_LAT_DEG;
        TargetPoint.LongitudeDeg = SourcePoint.LongitudeDeg + ProjectiveConstants::DELTA_LON_DEG;
        TargetPoint.ElevationMeters = SourcePoint.ElevationMeters * ProjectiveConstants::AFFINE_SCALE_W;
        return TargetPoint;
    }

    static Vector4P GeodeticToProjective(const GeodeticPoint& Geo, double R = ProjectiveConstants::REFERENCE_GEOID_RADIUS_M) {
        double latRad = Geo.LatitudeDeg * (M_PI / 180.0);
        double lonRad = Geo.LongitudeDeg * (M_PI / 180.0);
        double rEff = R + Geo.ElevationMeters;

        Vector4P P;
        P.X = rEff * std::cos(latRad) * std::cos(lonRad);
        P.Y = rEff * std::cos(latRad) * std::sin(lonRad);
        P.Z = rEff * std::sin(latRad);
        P.W = R * ProjectiveConstants::AFFINE_SCALE_W;
        return P.Normalize();
    }

    static double FubiniStudyMetric(const Vector4P& P1, const Vector4P& P2) {
        double dot = P1.X * P2.X + P1.Y * P2.Y + P1.Z * P2.Z + P1.W * P2.W;
        double norm1 = std::sqrt(P1.X*P1.X + P1.Y*P1.Y + P1.Z*P1.Z + P1.W*P1.W);
        double norm2 = std::sqrt(P2.X*P2.X + P2.Y*P2.Y + P2.Z*P2.Z + P2.W*P2.W);
        if (norm1 * norm2 == 0.0) return 0.0;
        double cosVal = std::abs(dot) / (norm1 * norm2);
        if (cosVal > 1.0) cosVal = 1.0;
        return std::acos(cosVal);
    }

    static EMetricQuadrant ResolveQuadrant(const GeodeticPoint& Pt) {
        if (Pt.LatitudeDeg >= 50.0) {
            return Quadrant_I;
        } else if (Pt.LatitudeDeg >= 46.0 && Pt.LatitudeDeg < 48.0 && Pt.LongitudeDeg >= 33.0) {
            return Quadrant_IV;
        } else if (Pt.LongitudeDeg < 32.0) {
            return Quadrant_II;
        } else {
            return Quadrant_III;
        }
    }
};

}} // namespace P3Engine::Math
