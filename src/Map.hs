{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Map where

import qualified Data.Map as M
import Types
import Data.Tiled

importScale :: Double
importScale = 1


parseLayers :: Maybe (Tileset, FilePath) -> [Layer] -> Int -> Int -> [Form]
parseLayers tileset ls = tiledata
  where
    tiledata       = parseTileset tileset $ getLayer "tiles"
    getLayer name  = listToMaybe $ filter ((== name) . layerName) ls



parseTileset :: Maybe (Tileset, FilePath) -> Maybe Layer -> Int -> Int -> [Form]
parseTileset (Just (ts, fp)) (Just Layer {layerData}) x y = fmap toTile
                                                          . maybeToList
                                                          $ M.lookup (x, y) layerData
  where
    toTile :: Tile -> Form
    toTile (tileGid -> t)
      = move (V2 (fromIntegral x) (fromIntegral y) ^* (16 * importScale))
      . group
      . pure
      . scale (importScale + 0.01)
      . toForm
      $ croppedImage (getCrop t) fp

    getCrop :: Word32 -> Crop
    getCrop (subtract 1 . fromIntegral -> g) =
      Crop ((g `mod` stride) * 16) ((g `div` stride) * 16) 16 16

    stride = let img = head $ tsImages ts
              in iWidth img `div` 16

parseTileset _ _ _ _ = []


maps :: [(String, Int -> Int -> [Form])]
maps = zip names
          $ map (\x ->
              parseLayers (fmap getTileset . listToMaybe $ mapTilesets x)
                          (mapLayers x)
                )
          . unsafePerformIO
          . sequence
          . map (\n -> loadMapFile $ "maps/" ++ n ++ ".tmx")
          $ names
  where
    names = [ "mindfuck"
            ]
{-# NOINLINE maps #-}


getTileset :: Tileset -> (Tileset, FilePath)
getTileset x = (x, ("maps/" ++) . iSource . head $ tsImages x)

