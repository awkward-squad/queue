-- |
--
-- Performance comparison to other types:
--
--   +---+------------------------------+------------------+
--   |   | @EphemeralQueue@             |                  |
--   +===+==============================+==================+
--   | ✔ | is @6.37x@ faster than       | @Seq@            |
--   +---+------------------------------+                  |
--   | ✔ | allocates @0.18x@ as much as |                  |
--   +---+------------------------------+------------------+
--   | ✔ | is @4.71x@ faster than       | "Queue"          |
--   +---+------------------------------+                  |
--   | ✔ | allocates @0.31x@ as much as |                  |
--   +---+------------------------------+------------------+
--   | ✔ | is @2.54x@ faster than       | "RealTimeQueue"  |
--   +---+------------------------------+                  |
--   | ✔ | allocates @0.47x@ as much as |                  |
--   +---+------------------------------+------------------+
module EphemeralQueue
  ( -- * Queue
    EphemeralQueue (Empty, Front),

    -- ** Initialization
    empty,
    singleton,

    -- * Basic interface
    enqueue,
    dequeue,

    -- ** Extended interface
    enqueueFront,
    dequeueWhile,

    -- * Queries
    isEmpty,

    -- * Transformations
    map,
    traverse,

    -- * List conversions
    fromList,
    toList,
  )
where

import Data.Foldable qualified as Foldable
import Data.Traversable qualified as Traversable
import Prelude hiding (foldMap, length, map, span, traverse)

data EphemeralQueue a
  = Q [a] [a]
  deriving stock (Eq, Functor)

-- TODO
instance Foldable EphemeralQueue where
  foldMap = undefined

instance Monoid (EphemeralQueue a) where
  mempty :: EphemeralQueue a
  mempty =
    empty

instance Semigroup (EphemeralQueue a) where
  (<>) :: EphemeralQueue a -> EphemeralQueue a -> EphemeralQueue a
  Empty <> ys = ys
  Front x xs <> ys = enqueue x (xs <> ys)

instance (Show a) => Show (EphemeralQueue a) where
  show :: EphemeralQueue a -> String
  show = show . toList

instance Traversable EphemeralQueue where
  traverse :: (Applicative f) => (a -> f b) -> EphemeralQueue a -> f (EphemeralQueue b)
  traverse =
    traverse

-- | An empty queue.
pattern Empty :: EphemeralQueue a
pattern Empty <- (dequeue -> Nothing)

-- | The front of a queue, and the rest of it.
pattern Front :: a -> EphemeralQueue a -> EphemeralQueue a
pattern Front x xs <- (dequeue -> Just (x, xs))

{-# COMPLETE Empty, Front #-}

-- | An empty queue.
empty :: EphemeralQueue a
empty =
  Q [] []

-- | A singleton queue.
singleton :: a -> EphemeralQueue a
singleton x =
  Q [x] []

enqueue :: a -> EphemeralQueue a -> EphemeralQueue a
enqueue y (Q xs ys) =
  Q xs (y : ys)
{-# INLINEABLE enqueue #-}

dequeue :: EphemeralQueue a -> Maybe (a, EphemeralQueue a)
dequeue = \case
  Q [] ys ->
    case reverse ys of
      [] -> Nothing
      x : xs -> Just (x, Q xs [])
  Q (x : xs) ys -> Just (x, Q xs ys)
{-# INLINEABLE dequeue #-}

enqueueFront :: a -> EphemeralQueue a -> EphemeralQueue a
enqueueFront x (Q xs ys) =
  Q (x : xs) ys
{-# INLINEABLE enqueueFront #-}

-- | Dequeue elements from the front of a queue while a predicate is satisfied.
dequeueWhile :: (a -> Bool) -> EphemeralQueue a -> ([a], EphemeralQueue a)
dequeueWhile p queue0 =
  case span p empty queue0 of
    (queue1, queue2) -> (toList queue1, queue2)
{-# INLINEABLE dequeueWhile #-}

span :: (a -> Bool) -> EphemeralQueue a -> EphemeralQueue a -> (EphemeralQueue a, EphemeralQueue a)
span p =
  go
  where
    go acc = \case
      Empty -> (acc, empty)
      Front x xs
        | p x -> go (enqueue x acc) xs
        | otherwise -> (acc, enqueueFront x xs)

isEmpty :: EphemeralQueue a -> Bool
isEmpty = \case
  Q [] [] -> True
  _ -> False
{-# INLINEABLE isEmpty #-}

map :: (a -> b) -> EphemeralQueue a -> EphemeralQueue b
map =
  fmap

traverse :: (Applicative f) => (a -> f b) -> EphemeralQueue a -> f (EphemeralQueue b)
traverse f (Q xs ys) =
  Q
    <$> Traversable.traverse f xs
    <*> backwards ys
  where
    backwards =
      go
      where
        go = \case
          [] -> pure []
          z : zs -> flip (:) <$> go zs <*> f z
{-# INLINEABLE traverse #-}

fromList :: [a] -> EphemeralQueue a
fromList xs =
  Q xs []
{-# INLINEABLE fromList #-}

toList :: EphemeralQueue a -> [a]
toList (Q xs ys) =
  xs ++ reverse ys
{-# INLINEABLE toList #-}
