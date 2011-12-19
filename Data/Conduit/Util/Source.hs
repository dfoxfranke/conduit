{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
-- | Utilities for constructing and converting 'Source', 'SourceM' and
-- 'BSource' types. Please see "Data.Conduit.Types.Source" for more information
-- on the base types.
module Data.Conduit.Util.Source
    ( sourceM
    , transSourceM
    , sourceMState
    ) where

import Control.Monad.Trans.Resource (ResourceT, transResourceT, Resource (..))
import Data.Conduit.Types.Source
import Control.Monad (liftM)

-- | Construct a 'SourceM' with some stateful functions. This function address
-- all mutable state for you.
sourceMState
    :: Resource m
    => state -- ^ Initial state
    -> (state -> ResourceT m (state, SourceResult output)) -- ^ Pull function
    -> SourceM m output
sourceMState state0 pull = sourceM
    (newRef state0)
    (const $ return ())
    (\istate -> do
        state <- readRef istate
        (state', res) <- pull state
        writeRef istate state'
        return res)

-- | Construct a 'SourceM'.
sourceM :: Monad m
        => ResourceT m state -- ^ resource and/or state allocation
        -> (state -> ResourceT m ()) -- ^ resource and/or state cleanup
        -> (state -> ResourceT m (SourceResult output)) -- ^ Pull function. Note that this need not explicitly perform any cleanup.
        -> SourceM m output
sourceM alloc cleanup pull = SourceM $ do
    state <- alloc
    return Source
        { sourcePull = pull state
        , sourceClose = cleanup state
        }

-- | Transform the monad a 'SourceM' lives in.
transSourceM :: (Base m ~ Base n, Monad m)
             => (forall a. m a -> n a)
             -> SourceM m output
             -> SourceM n output
transSourceM f (SourceM mc) =
    SourceM (transResourceT f (liftM go mc))
  where
    go c = c
        { sourcePull = transResourceT f (sourcePull c)
        , sourceClose = transResourceT f (sourceClose c)
        }
