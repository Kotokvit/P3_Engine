#include "P3TopologyMath.h"
#include <iostream>
#include <iomanip>

using namespace P3Engine::Math;

int main() {
    std::cout << "=== P3 PURE TOPOLOGICAL MANIFOLD ENGINE ===\n\n";

    // Tensor shift test on arbitrary coordinates
    GeodeticPoint P_src = { 50.4489, 30.5133, 140.0 };
    GeodeticPoint P_dst = TopologyConjugator::TransformGeodetic(P_src);

    std::cout << "Input Geodetic Point:  [" << P_src.LatitudeDeg << " deg, " << P_src.LongitudeDeg << " deg, " << P_src.ElevationMeters << " m]\n";
    std::cout << "Mapped Geodetic Point: [" << std::fixed << std::setprecision(4) 
              << P_dst.LatitudeDeg << " deg, " << P_dst.LongitudeDeg << " deg, " << P_dst.ElevationMeters << " m]\n";
    std::cout << "Resolved Quadrant:     " << static_cast<int>(TopologyConjugator::ResolveQuadrant(P_dst)) << "\n\n";

    // RP^3 embedding & Fubini-Study Riemannian Distance
    Vector4P v1 = TopologyConjugator::GeodeticToProjective(P_src);
    Vector4P v2 = TopologyConjugator::GeodeticToProjective(P_dst);
    double d_FS = TopologyConjugator::FubiniStudyMetric(v1, v2);

    std::cout << "Fubini-Study Distance d_FS(P_src, P_dst) = " << std::setprecision(6) << d_FS << " rad\n";
    std::cout << "===========================================\n";

    return 0;
}
