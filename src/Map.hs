{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ViewPatterns      #-}

module Map where

import JumpGrid
import           Data.Graph.AStar
import qualified Data.HashSet as HS
import qualified Data.Map as M
import           Data.Tiled
import           Overture hiding (distance)


tileWidth :: Num t => t
tileWidth = 64


tileHeight :: Num t => t
tileHeight = 32


getTileCrop :: Tileset -> Word32 -> Form
getTileCrop ts = \gid ->
  let g      = fromIntegral $ gid - tsInitialGid ts
      img    = head $ tsImages ts
      fs     = iSource img
      stride = iWidth img `div` tileWidth
      crop   = Crop (g `mod` stride * tileWidth)
                    (g `div` stride * tileHeight)
                    tileWidth
                    tileHeight
   -- TODO(sandy): probably smarter to do this shifting later, when we draw it
   in move (negate $ V2 halfTileWidth halfTileHeight)
    . toForm
    . croppedImage crop
    $ "maps/" <> fs


drawSquare :: Layer -> [Tileset] -> Int -> Int -> Maybe Form
drawSquare (Layer {..}) ts = \x y ->
  M.lookup (x, y) layerData <&> \(tileGid -> gid) ->
    getTileCrop (getTilesetForGid ts gid) gid
drawSquare _ _ = error "terrible layer choice"


getTilesetForGid :: [Tileset] -> Word32 -> Tileset
getTilesetForGid ts gid = head $ dropWhile ((> gid) . tsInitialGid) ts


orderTilesets :: [Tileset] -> [Tileset]
orderTilesets = sortBy . flip $ comparing tsInitialGid


parseMap :: TiledMap -> Map
parseMap TiledMap{..} =
    Map (drawSquare ground ts)
        (drawSquare doodads ts)
        (NavMesh (isOpenTile grid) $ findPath grid)
        mapWidth
        mapHeight
  where
    getLayer name = maybe (error $ "no " <> name <> " layer") id
                  $ find ((== name) . layerName) mapLayers
    ground    = getLayer "ground"
    doodads   = getLayer "doodads"
    collision = getLayer "collision"
    grid = makeGrid2 mapWidth mapHeight collision
    ts = orderTilesets mapTilesets


makeGrid
    :: Int
    -> Int
    -> Layer
    -> (Int, Int)
    -> (Int, Int)
    -> Maybe [(Int, Int)]
makeGrid w h l = \src dst ->
    fmap (src :) $ aStar neighbors distance (distance dst) (== dst) src
  where
    neighbors (x, y) = HS.fromList $ do
      dx <- [-1, 0, 1]
      dy <- [-1, 0, 1]
      let x' = dx + x
          y' = dy + y
      guard $ dx /= 0 || dy /= 0
      guard $ x' >= 0
      guard $ y' >= 0
      guard $ x' < w
      guard $ y' < h
      guard $ not $ checkLayer l (x, y)
      pure (x', y')

    distance (ax, ay) (bx, by) = quadrance $ V2 ax ay - V2 bx by


makeGrid2 :: Int -> Int -> Layer -> JumpGrid
makeGrid2 w h l = foldl' f (make (w, h)) $ M.toList $ layerData l
  where
    f j (xy, _) = changeArea False xy xy j


checkLayer :: Layer -> (Int, Int) -> Bool
checkLayer l xy = maybe False (const True) $  M.lookup xy $ layerData l


maps :: M.Map String Map
maps = M.fromList $
  [ "hoth"
  ]
  <&> \i -> ( i
            , parseMap . unsafePerformIO
                       . loadMapFile
                       $ "maps/" <> i <> ".tmx"
            )
{-# NOINLINE maps #-}

