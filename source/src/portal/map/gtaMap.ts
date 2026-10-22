import L from 'leaflet'

import type { PortalCoordinates } from '@/portal/portal.types'

export const MAXIMUM_MAP_ZOOM = 5

/** The part of the world the map can show. */
export const mapBounds = L.latLngBounds([
    [-4000, -5500],
    [8000, 6000],
])

/** Maps GTA world coordinates onto the satellite image. */
export const gtaCrs = Object.assign({}, L.CRS.Simple, {
    projection: L.Projection.LonLat,

    scale(zoom: number) {
        return 2 ** zoom
    },

    zoom(scale: number) {
        return Math.log(scale) / Math.LN2
    },

    distance(firstPoint: L.LatLng, secondPoint: L.LatLng) {
        return Math.hypot(
            secondPoint.lng - firstPoint.lng,
            secondPoint.lat - firstPoint.lat,
        )
    },

    transformation: new L.Transformation(
        0.02072,
        117.3,
        -0.0205,
        172.8,
    ),

    infinite: true,
})

/** GTA x/y to a map position (the map is latitude first). */
export function toLatLng(coordinates: PortalCoordinates): L.LatLngExpression {
    return [coordinates.y, coordinates.x]
}