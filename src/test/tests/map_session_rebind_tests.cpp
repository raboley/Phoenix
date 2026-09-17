#include "common/scheduler.h"
#include "map/map_session.h"
#include "map/map_session_container.h"

#include <catch2/catch_test_macros.hpp>

struct MapSessionContainerTestAccess
{
    static auto add(MapSessionContainer& container, const IPP& ipp, uint32 charId, BLOWFISH status) -> MapSession*
    {
        auto session             = std::make_unique<MapSession>();
        session->scheduler       = &container.scheduler_;
        session->client_ipp      = ipp;
        session->charID          = charId;
        session->blowfish.status = status;
        auto* ptr                = session.get();
        container.sessions_.emplace(ipp, std::move(session));
        return ptr;
    }
};

TEST_CASE("zoning session can move to a new UDP source port", "[map_session_rebind]")
{
    Scheduler           scheduler(1);
    MapSessionContainer sessions(scheduler);
    const IPP           oldEndpoint(str2ip("127.0.0.1"), 55001);
    const IPP           newEndpoint(str2ip("127.0.0.1"), 55002);
    auto*               original = MapSessionContainerTestAccess::add(sessions, oldEndpoint, 7340033, BLOWFISH_PENDING_ZONE);

    REQUIRE(sessions.rebindZoningSession(7340033, newEndpoint) == original);
    CHECK(sessions.getSessionByIPP(oldEndpoint) == nullptr);
    CHECK(sessions.getSessionByIPP(newEndpoint) == original);
    CHECK(original->client_ipp == newEndpoint);
    CHECK(original->charID == 7340033);
}

TEST_CASE("endpoint reuse while multiple characters zone preserves both arrivals", "[map_session_rebind]")
{
    Scheduler           scheduler(1);
    MapSessionContainer sessions(scheduler);
    const IPP           firstEndpoint(str2ip("127.0.0.1"), 55001);
    const IPP           secondEndpoint(str2ip("127.0.0.1"), 55002);
    const IPP           thirdEndpoint(str2ip("127.0.0.1"), 55003);
    MapSessionContainerTestAccess::add(sessions, firstEndpoint, 7340033, BLOWFISH_PENDING_ZONE);
    MapSessionContainerTestAccess::add(sessions, secondEndpoint, 7340032, BLOWFISH_PENDING_ZONE);

    // The second player's new port is still owned by the first player's old session.
    auto* second = sessions.rebindZoningSession(7340032, firstEndpoint);
    REQUIRE(second != nullptr);
    CHECK(sessions.getSessionByCharId(7340033) != nullptr);
    CHECK(sessions.getSessionByIPP(firstEndpoint) == second);
    auto* first = sessions.getSessionByCharId(7340033);
    CHECK(sessions.rebindZoningSession(7340033, thirdEndpoint) == first);
    CHECK(sessions.getSessionByIPP(thirdEndpoint) == first);
}

TEST_CASE("active and cross-IP sessions cannot be rebound", "[map_session_rebind]")
{
    Scheduler           scheduler(1);
    MapSessionContainer sessions(scheduler);
    const IPP           oldEndpoint(str2ip("127.0.0.1"), 55001);
    const IPP           newEndpoint(str2ip("127.0.0.1"), 55002);
    const IPP           remoteEndpoint(str2ip("127.0.0.2"), 55003);
    auto*               active = MapSessionContainerTestAccess::add(sessions, oldEndpoint, 7340033, BLOWFISH_ACCEPTED);

    CHECK(sessions.rebindZoningSession(7340033, newEndpoint) == nullptr);
    active->blowfish.status = BLOWFISH_PENDING_ZONE;
    CHECK(sessions.rebindZoningSession(7340033, remoteEndpoint) == nullptr);
    CHECK(sessions.getSessionByIPP(oldEndpoint) == active);
}

TEST_CASE("a zoning session cannot take an active player's endpoint", "[map_session_rebind]")
{
    Scheduler           scheduler(1);
    MapSessionContainer sessions(scheduler);
    const IPP           zoningEndpoint(str2ip("127.0.0.1"), 55001);
    const IPP           activeEndpoint(str2ip("127.0.0.1"), 55002);
    auto*               zoning = MapSessionContainerTestAccess::add(sessions, zoningEndpoint, 7340033, BLOWFISH_PENDING_ZONE);
    auto*               active = MapSessionContainerTestAccess::add(sessions, activeEndpoint, 7340032, BLOWFISH_ACCEPTED);

    CHECK(sessions.rebindZoningSession(7340033, activeEndpoint) == nullptr);
    CHECK(sessions.getSessionByIPP(zoningEndpoint) == zoning);
    CHECK(sessions.getSessionByIPP(activeEndpoint) == active);
}
