{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

-- | Please see the project README for more details:
--
--   https://github.com/jwiegley/simple-conduit/blob/master/README.md
--
--   Also see this blog article:
--
--   https://www.newartisans.com/2014/06/simpler-conduit-library

module Conduit.Simple
    ( Source(..), Conduit, Sink
    , sequenceSources
    , ZipSink(..), sequenceSinks
    , runSource, lowerSource, source, conduit, conduitWith, sink
    , ($=), (=$), ($$)
    , returnC, close, skip, awaitForever
    , yieldMany, sourceList
    , unfoldC
    , enumFromToC
    , iterateC
    , repeatC
    , replicateC
    , sourceLazy
    , repeatMC
    , repeatWhileMC
    , replicateMC
    , sourceHandle
    , sourceFile
    , sourceIOHandle
    , stdinC
    , initRepeat
    , initReplicate
    , sourceRandom
    , sourceRandomN
    , sourceRandomGen
    , sourceRandomNGen
    , sourceDirectory
    , sourceDirectoryDeep
    , dropC
    , dropCE
    , dropWhileC
    , dropWhileCE
    , foldC
    , foldCE
    , foldlC
    , foldlCE
    , foldMapC
    , foldMapCE
    , allC
    , allCE
    , anyC
    , anyCE
    , andC
    , andCE
    , orC
    , orCE
    , elemC
    , elemCE
    , notElemC
    , notElemCE
    , sinkLazy
    , sinkList
    , sinkVector
    , sinkVectorN
    , sinkBuilder
    , sinkLazyBuilder
    , sinkNull
    , awaitNonNull
    , headCE
    , lastC
    , lastCE
    , lengthC
    , lengthCE
    , lengthIfC
    , lengthIfCE
    , maximumC
    , maximumCE
    , minimumC
    , minimumCE
    , sumC
    , sumCE
    , productC
    , productCE
    , findC
    , mapM_C
    , mapM_CE
    , foldMC
    , foldMCE
    , foldMapMC
    , foldMapMCE
    , sinkFile
    , sinkHandle
    , sinkIOHandle
    , printC
    , stdoutC
    , stderrC
    , mapC
    , mapCE
    , omapCE
    , concatMapC
    , concatMapCE
    , takeC
    , takeCE
    , takeWhileC
    , takeWhileCE
    , takeExactlyC
    , takeExactlyCE
    , concatC
    , filterC
    , filterCE
    , mapWhileC
    , conduitVector
    , scanlC
    , concatMapAccumC
    , intersperseC
    , encodeBase64C
    , decodeBase64C
    , encodeBase64URLC
    , decodeBase64URLC
    , encodeBase16C
    , decodeBase16C
    , mapMC
    , mapMCE
    , omapMCE
    , concatMapMC
    , filterMC
    , filterMCE
    , iterMC
    , scanlMC
    , concatMapAccumMC
    , encodeUtf8C
    , decodeUtf8C
    , lineC
    , lineAsciiC
    , unlinesC
    , unlinesAsciiC
    , linesUnboundedC_
    , linesUnboundedC, linesC
    , linesUnboundedAsciiC, linesAsciiC
    , zipSinks
    , sourceMaybeMVar
    , sourceMaybeTMVar
    , asyncC
    , fromFoldM
    , toFoldM
    , sourceTChan
    , sourceTQueue
    , sourceTBQueue
    , untilMC
    , whileMC
    ) where

import           Control.Applicative (Alternative((<|>), empty),
                                      Applicative((<*>), pure), (<$>))
import           Control.Concurrent (MVar, takeMVar, putMVar, newEmptyMVar)
import           Control.Concurrent.Async.Lifted (Async, withAsync, waitBoth,
                                                  async)
import           Control.Concurrent.STM
import           Control.Exception.Lifted (bracket)
import           Control.Foldl (PrimMonad, Vector, FoldM(..))
import           Control.Monad.Base (MonadBase(..))
import           Control.Monad.Catch (MonadThrow(..), MonadMask, MonadCatch)
import qualified Control.Monad.Catch as Catch
import           Control.Monad.Cont
import           Control.Monad.Error.Class (MonadError(..))
import           Control.Monad.Free
import           Control.Monad.Morph (MMonad(..), MFunctor(..))
import           Control.Monad.Primitive (PrimMonad(PrimState))
import           Control.Monad.Reader.Class (MonadReader(..))
import           Control.Monad.State.Class (MonadState(..))
import           Control.Monad.Trans.Control (MonadBaseControl(StM))
import           Control.Monad.Trans.Either (EitherT(..), left)
import           Control.Monad.Writer.Class (MonadWriter(..))
import           Data.Bifunctor (Bifunctor(bimap))
import           Data.Builder (Builder(builderToLazy), ToBuilder(..))
import           Data.ByteString (ByteString)
import           Data.Foldable (Foldable(foldMap))
import           Data.Functor.Identity
import           Data.IOData (IOData(hGetChunk, hPut))
import           Data.List (unfoldr)
import           Data.MonoTraversable (MonoTraversable, MonoFunctor, Element,
                                       MonoFoldable(oall, oany, ofoldMap,
                                                    ofoldl', ofoldlM, olength,
                                                    onull))
import           Data.NonNull as NonNull (NonNull, fromNullable)
import           Data.Semigroup (Any(..), All(..), Monoid(..), Semigroup((<>)))
import           Data.Sequences as Seq (OrdSequence, EqSequence(elem, notElem),
                                        SemiSequence(Index), singleton,
                                        IsSequence(break, drop, dropWhile,
                                                   fromList, splitAt))
import           Data.Sequences.Lazy (LazySequence(fromChunks, toChunks))
import qualified Data.Streaming.Filesystem as F
import           Data.Text (Text)
import           Data.Textual.Encoding (Utf8(encodeUtf8))
import           Data.Traversable (Traversable(sequenceA))
import           Data.Word (Word8)
import           System.FilePath ((</>))
import           System.IO (stdout, stdin, stderr, openFile, hClose,
                            Handle, IOMode(ReadMode, WriteMode))
import           System.Random.MWC as MWC (Gen, Variate(uniform),
                                           createSystemRandom)

{-

[] is isomorphic to
(a -> r -> r) -> r -> r, which is the same as
Cont (r -> r) a

This is also isomorphic to an F-algebra of the function functor:
Algebra ((->) a) (r -> r)

m [] is isomorphic to
(a -> r -> m r) -> r -> m r, which is the same as
Cont (r -> m r) a, and
Algebra ((->) a) (r -> m r)
-}

-- | A Source is a short-circuiting monadic fold.
--
-- 'Source' forms a Monad that behaves as a 'ListT'; for example:
--
-- @
-- do line <- sourceFile "foo.txt"
--    liftIO $ putStrLn $ "line: " ++ show line
--    x <- yieldMany [1..10]
--    return (x, line)
-- @
--
-- The above Source yields a series of pairs, providing ten copies of each
-- line from the file plus an index number.
--
-- To skip to the next value in a Source, use the function 'skip' or 'mempty';
-- to close the source, use 'close'.  For example:
--
-- @
-- do x <- yieldMany [1..10]
--    if x == 2 || x == 9
--    then return x
--    else if x < 5
--         then skip
--         else close
-- @
--
-- This outputs the list @[2]@.
--
-- One difference from the @conduit@ library is that monadic chaining of
-- sources with '>>' results in the values from the first source being used to
-- determine how many values are generated by the next source, just like
-- 'ListT':
--
-- >>> sinkList $ yieldMany [1..3] >> yieldMany [4..6]
-- [4,5,6,4,5,6,4,5,6]
--
-- To achieve the same behavior as in @conduit@, use the Monoid instance for
-- Sources:
--
-- >>> sinkList $ yieldMany [1..3] <> yieldMany [4..6]
-- [1,2,3,4,5,6]
newtype Source m a = Source { getSource :: forall r. Cont (r -> EitherT r m r) a }
    deriving Functor

-- | A 'Conduit' is a "Source homomorphism", or simple a mapping between
--   sources.  There is no need for it to be a type synonym, except to save
--   repetition across type signatures.
type Conduit a m b = Source m a -> Source m b

-- | A 'Sink' folds a 'Source' down to its result value.  It is simply a
--   convenient type synonym for functions mapping a 'Source' to some result
--   type.
type Sink a m r = Source m a -> m r

instance Monad m => Semigroup (Source m a) where
    x <> y = source $ \r c -> runSource x r c >>= \r' -> runSource y r' c
    {-# INLINE (<>) #-}

instance Monad m => Monoid (Source m a) where
    mempty  = skip
    {-# INLINE mempty #-}
    mappend = (<>)
    {-# INLINE mappend #-}

instance Monad m => Alternative (Source m) where
    empty = skip
    {-# INLINE empty #-}
    (<|>) = (<>)
    {-# INLINE (<|>) #-}

instance Monad m => MonadPlus (Source m) where
    mzero = skip
    {-# INLINE mzero #-}
    mplus = (<|>)
    {-# INLINE mplus #-}

instance Applicative (Source m) where
    pure  = return
    {-# INLINE pure #-}
    (<*>) = ap
    {-# INLINE (<*>) #-}

instance Monad (Source m) where
    return x = source $ \z yield -> yield z x
    {-# INLINE return #-}
    m >>= f = source $ \z c -> runSource m z $ \r x -> runSource (f x) r c
    {-# INLINE (>>=) #-}

instance MFunctor Source where
    hoist nat m = source $ \z yield -> runSource (hoist nat m) z yield
    {-# INLINE hoist #-}

instance MMonad Source where
    embed f m = source $ \z yield -> runSource (embed f m) z yield
    {-# INLINE embed #-}

instance MonadIO m => MonadIO (Source m) where
    liftIO m = source $ \r yield -> liftIO m >>= yield r
    {-# INLINE liftIO #-}

instance MonadTrans Source where
    lift m = source $ \z yield -> yield z =<< lift m
    {-# INLINE lift #-}

instance (Functor f, MonadFree f m) => MonadFree f (Source m) where
    wrap t = source $ \r h -> wrap $ fmap (\p -> runSource p r h) t
    {-# INLINE wrap #-}

-- jww (2014-06-15): If it weren't for the universally quantified r...
-- instance MonadCont (Source m) where
--     callCC f = source $ \z c -> runSource (f (\x -> source $ \r _ -> c r x)) z c
--     {-# INLINE callCC #-}

instance MonadReader r m => MonadReader r (Source m) where
    ask = lift ask
    {-# INLINE ask #-}
    local f = conduit $ \r yield -> local f . yield r
    {-# INLINE local #-}
    reader = lift . reader
    {-# INLINE reader #-}

instance MonadState s m => MonadState s (Source m) where
    get = lift get
    {-# INLINE get #-}
    put = lift . put
    {-# INLINE put #-}
    state = lift . state
    {-# INLINE state #-}

instance MonadWriter w m => MonadWriter w (Source m) where
    writer = lift . writer
    {-# INLINE writer #-}
    tell = lift . tell
    {-# INLINE tell #-}
    listen = conduit $ \r yield x -> do
        ((), w) <- listen $ return ()
        yield r (x, w)
    {-# INLINE listen #-}
    pass = conduit $ \r yield (x, f) -> do
        pass $ return ((), f)
        yield r x
    {-# INLINE pass #-}

instance MonadError e m => MonadError e (Source m) where
    throwError = lift . throwError
    {-# INLINE throwError #-}
    catchError src f = source $ \z yield -> EitherT $
        runEitherT (runSource src z yield)
            `catchError` \e -> runEitherT (runSource (f e) z yield)
    {-# INLINE catchError #-}

instance MonadThrow m => MonadThrow (Source m) where
    throwM = lift . throwM
    {-# INLINE throwM #-}

instance MonadCatch m => MonadCatch (Source m) where
    catch src f = source $ \z yield -> EitherT $
        runEitherT (runSource src z yield)
            `Catch.catch` \e -> runEitherT (runSource (f e) z yield)
    {-# INLINE catch #-}

instance MonadMask m => MonadMask (Source m) where
    mask a = source $ \z yield -> EitherT $ Catch.mask $ \u ->
        runEitherT $ runSource (a $ \b -> source $ \r yield' ->
            EitherT $ liftM Right $ u $ sink r yield' b) z yield
    {-# INLINE mask #-}
    uninterruptibleMask a =
        source $ \z yield -> EitherT $ Catch.uninterruptibleMask $ \u ->
            runEitherT $ runSource (a $ \b -> source $ \r yield' ->
                EitherT $ liftM Right $ u $ sink r yield' b) z yield
    {-# INLINE uninterruptibleMask #-}

instance Foldable (Source Identity) where
    foldMap f = runIdentity . sink mempty (\r x -> return $ r `mappend` f x)
    {-# INLINE foldMap #-}

-- | Sequence a collection of sources.
--
-- >>> sinkList $ sequenceSources [yieldOne 1, yieldOne 2, yieldOne 3]
-- [[1,2,3]]
sequenceSources :: (Traversable f, Monad m) => f (Source m a) -> Source m (f a)
sequenceSources = sequenceA
{-# INLINE sequenceSources #-}

-- | Compose a 'Source' and a 'Conduit' into a new 'Source'.  Note that this
--   is just flipped function application, so ($) can be used to achieve the
--   same thing.
infixl 1 $=
($=) :: a -> (a -> b) -> b
($=) = flip ($)
{-# INLINE ($=) #-}

-- | Compose a 'Conduit' and a 'Sink' into a new 'Sink'.  Note that this is
--   just function composition, so (.) can be used to achieve the same thing.
infixr 2 =$
(=$) :: (a -> b) -> (b -> c) -> a -> c
(=$) = flip (.)
{-# INLINE (=$) #-}

-- | Compose a 'Source' and a 'Sink' and compute the result.  Note that this
--   is just flipped function application, so ($) can be used to achieve the
--   same thing.
infixr 0 $$
($$) :: a -> (a -> b) -> b
($$) = flip ($)
{-# INLINE ($$) #-}

awaitForever :: (a -> Source m b) -> Conduit a m b
awaitForever = flip (>>=)
{-# INLINE awaitForever #-}

-- | Promote any sink to a source.  This can be used as if it were a source
--   transformer (aka, a conduit):
--
-- >>> sinkList $ returnC $ sumC $ mapC (+1) $ yieldMany [1..10]
-- [65]
--
-- Note that 'returnC' is a synonym for 'Control.Monad.Trans.Class.lift'.
returnC :: Monad m => m a -> Source m a
returnC = lift
{-# INLINE returnC #-}

close :: Monad m => Source m a
close = source $ const . left
{-# INLINE close #-}

skip :: Monad m => Source m a
skip = source $ const . return
{-# INLINE skip #-}

runSource :: Source m a -> r -> (r -> a -> EitherT r m r) -> EitherT r m r
runSource (Source (ContT src)) z yield =
    runIdentity (src (\x -> Identity $ \r -> yield r x)) z
{-# INLINE runSource #-}

lowerSource :: (Monad m, Monoid a) => Source m a -> m a
lowerSource src = unwrap id $ runSource src mempty ((return .) . mappend)
{-# INLINE lowerSource #-}

source :: (forall r. r -> (r -> a -> EitherT r m r) -> EitherT r m r) -> Source m a
source await = Source $ ContT $ \yield -> Identity $ \z ->
    await z (\r x -> runIdentity (yield x) r)
{-# INLINE source #-}

conduit :: (forall r. r -> (r -> b -> EitherT r m r) -> a -> EitherT r m r)
        -> Conduit a m b
conduit f src = source $ \z c -> runSource src z (`f` c)
{-# INLINE conduit #-}

-- | Most of the time conduits pass the fold variable through unmolested, but
--   sometimes you need to ignore that variable and use your own within a
--   stage of the pipeline.  This is done by wrapping the fold variable in a
--   tuple and then unwrapping it when the conduit is done.  'conduitWith'
--   makes this transparent.
conduitWith :: Monad m
            => s
            -> (forall r. (r, s) -> (r -> b -> EitherT (r, s) m (r, s)) -> a
                -> EitherT (r, s) m (r, s))
            -> Conduit a m b
conduitWith s f src = source $ \z yield ->
    rewrap fst $ runSource src (z, s) $ \(r, t) ->
        f (r, t) (\r' -> rewrap (, t) . yield r')
{-# INLINE conduitWith #-}

unwrap :: Monad m => (a -> b) -> EitherT a m a -> m b
unwrap f k = either f f `liftM` runEitherT k
{-# INLINE unwrap #-}

rewrap :: Monad m => (a -> b) -> EitherT a m a -> EitherT b m b
rewrap f k = EitherT $ bimap f f `liftM` runEitherT k
{-# INLINE rewrap #-}

sink :: forall m a r. Monad m => r -> (r -> a -> EitherT r m r) -> Sink a m r
sink z f src = either id id `liftM` runEitherT (runSource src z f)
{-# INLINE sink #-}

yieldMany :: (Monad m, MonoFoldable mono) => mono -> Source m (Element mono)
yieldMany xs = source $ \z yield -> ofoldlM yield z xs
{-# INLINE yieldMany #-}

sourceList :: Monad m => [a] -> Source m a
sourceList xs = source $ \z yield -> foldM yield z xs
{-# INLINE sourceList #-}

unfoldC :: forall m a b. Monad m => (b -> Maybe (a, b)) -> b -> Source m a
unfoldC = (sourceList .) . Data.List.unfoldr
{-# INLINE unfoldC #-}

enumFromToC :: forall m a. (Monad m, Enum a, Eq a) => a -> a -> Source m a
enumFromToC = (sourceList .) . enumFromTo
{-# INLINE enumFromToC #-}

iterateC :: forall m a. Monad m => (a -> a) -> a -> Source m a
iterateC = (sourceList .) . iterate
{-# INLINE iterateC #-}

repeatC :: forall m a. Monad m => a -> Source m a
repeatC = sourceList . Prelude.repeat
{-# INLINE repeatC #-}

replicateC :: forall m a. Monad m => Int -> a -> Source m a
replicateC = (sourceList .) . Prelude.replicate
{-# INLINE replicateC #-}

sourceLazy :: (Monad m, LazySequence lazy strict) => lazy -> Source m strict
sourceLazy = sourceList . toChunks
{-# INLINE sourceLazy #-}

repeatMC :: forall m a. Monad m => m a -> Source m a
repeatMC x = source go
  where
    go :: r -> (r -> a -> EitherT r m r) -> EitherT r m r
    go z yield = loop z
      where
        loop r = loop =<< yield r =<< lift x

repeatWhileMC :: forall m a. Monad m => m a -> (a -> Bool) -> Source m a
repeatWhileMC m f = source go
  where
    go :: r -> (r -> a -> EitherT r m r) -> EitherT r m r
    go z yield = loop z
      where
        loop r = do
            x <- lift m
            if f x
                then loop =<< yield r x
                else return r

replicateMC :: forall m a. Monad m => Int -> m a -> Source m a
replicateMC n m = source $ go n
  where
    go :: Int -> r -> (r -> a -> EitherT r m r) -> EitherT r m r
    go i z yield = loop i z
      where
        loop n' r | n' > 0 = loop (n' - 1) =<< yield r =<< lift m
        loop _ r = return r

sourceHandle :: forall m a. (MonadIO m, IOData a) => Handle -> Source m a
sourceHandle h = source go
  where
    go :: r -> (r -> a -> EitherT r m r) -> EitherT r m r
    go z yield = loop z
      where
        loop y = do
            x <- liftIO $ hGetChunk h
            if onull x
                then return y
                else loop =<< yield y x

sourceFile :: (MonadBaseControl IO m, MonadIO m, IOData a)
           => FilePath -> Source m a
sourceFile path = source $ \z yield ->
    bracket (liftIO $ openFile path ReadMode) (liftIO . hClose)
        (\h -> runSource (sourceHandle h) z yield)
{-# INLINE sourceFile #-}

sourceIOHandle :: (MonadBaseControl IO m, MonadIO m, IOData a)
               => IO Handle -> Source m a
sourceIOHandle f = source $ \z yield ->
    bracket (liftIO f) (liftIO . hClose)
        (\h -> runSource (sourceHandle h) z yield)
{-# INLINE sourceIOHandle #-}

stdinC :: (MonadBaseControl IO m, MonadIO m, IOData a) => Source m a
stdinC = sourceHandle stdin
{-# INLINE stdinC #-}

initRepeat :: Monad m => m seed -> (seed -> m a) -> Source m a
initRepeat mseed f = source $ \z yield ->
    lift mseed >>= \seed -> runSource (repeatMC (f seed)) z yield
{-# INLINE initRepeat #-}

initReplicate :: Monad m => m seed -> (seed -> m a) -> Int -> Source m a
initReplicate mseed f n = source $ \z yield ->
    lift mseed >>= \seed -> runSource (replicateMC n (f seed)) z yield
{-# INLINE initReplicate #-}

sourceRandom :: (Variate a, MonadIO m) => Source m a
sourceRandom =
    initRepeat (liftIO MWC.createSystemRandom) (liftIO . MWC.uniform)
{-# INLINE sourceRandom #-}

sourceRandomN :: (Variate a, MonadIO m) => Int -> Source m a
sourceRandomN =
    initReplicate (liftIO MWC.createSystemRandom) (liftIO . MWC.uniform)
{-# INLINE sourceRandomN #-}

sourceRandomGen :: (Variate a, MonadBase base m, PrimMonad base)
                => Gen (PrimState base) -> Source m a
sourceRandomGen gen = initRepeat (return gen) (liftBase . MWC.uniform)
{-# INLINE sourceRandomGen #-}

sourceRandomNGen :: (Variate a, MonadBase base m, PrimMonad base)
                 => Gen (PrimState base) -> Int -> Source m a
sourceRandomNGen gen = initReplicate (return gen) (liftBase . MWC.uniform)
{-# INLINE sourceRandomNGen #-}

sourceDirectory :: forall m. (MonadBaseControl IO m, MonadIO m)
                => FilePath -> Source m FilePath
sourceDirectory dir = source $ \z yield ->
    bracket
        (liftIO (F.openDirStream dir))
        (liftIO . F.closeDirStream)
        (go z yield)
  where
    go :: r -> (r -> FilePath -> EitherT r m r) -> F.DirStream -> EitherT r m r
    go z yield ds = loop z
      where
        loop r = do
            mfp <- liftIO $ F.readDirStream ds
            case mfp of
                Nothing -> return r
                Just fp -> loop =<< yield r (dir </> fp)

sourceDirectoryDeep :: forall m. (MonadBaseControl IO m, MonadIO m)
                    => Bool -> FilePath -> Source m FilePath
sourceDirectoryDeep followSymlinks startDir = source go
  where
    go :: r -> (r -> FilePath -> EitherT r m r) -> EitherT r m r
    go z yield = start startDir z
      where
        start dir r = runSource (sourceDirectory dir) r entry
        entry r fp = do
            ft <- liftIO $ F.getFileType fp
            case ft of
                F.FTFile -> yield r fp
                F.FTFileSym -> yield r fp
                F.FTDirectory -> start fp r
                F.FTDirectorySym
                    | followSymlinks -> start fp r
                    | otherwise -> return r
                F.FTOther -> return r

dropC :: Monad m => Int -> Conduit a m a
dropC n = conduitWith n go
  where
    go (r, n') _ _ | n' > 0 = return (r, n' - 1)
    go (r, _) yield x       = yield r x
{-# INLINE dropC #-}

{-
dropCGen :: Monad m => Int -> FoldT (r, Int) m a -> FoldT r m a
dropCGen n = foldWith n go
  where
    go (r, n') _ _ | n' > 0 = return (r, n' - 1)
    go (r, _) yield x       = yield r x
{-# INLINE dropCGen #-}
-}

dropCE :: (Monad m, IsSequence seq) => Index seq -> Conduit seq m seq
dropCE n = conduitWith n go
  where
    go (r, n') yield s
        | onull y   = return (r, n' - xn)
        | otherwise = yield r y
      where
        (x, y) = Seq.splitAt n' s
        xn = n' - fromIntegral (olength x)

dropWhileC :: Monad m => (a -> Bool) -> Conduit a m a
dropWhileC f = conduitWith f go
  where
    go (r, k) _ x | k x = return (r, k)
    -- Change out the predicate for one that always fails
    go (r, _) yield x = fmap (const (const False)) <$> yield r x

dropWhileCE :: (Monad m, IsSequence seq)
            => (Element seq -> Bool)
            -> Conduit seq m seq
dropWhileCE f = conduitWith f go
  where
    go (r, k) yield s
        | onull x   = return (r, k)
        | otherwise = fmap (const (const False)) <$> yield r s
      where
        x = Seq.dropWhile k s

foldC :: (Monad m, Monoid a) => Sink a m a
foldC = foldMapC id
{-# INLINE foldC #-}

foldCE :: (Monad m, MonoFoldable mono, Monoid (Element mono))
       => Sink mono m (Element mono)
foldCE = foldlC (\acc mono -> acc `mappend` ofoldMap id mono) mempty
{-# INLINE foldCE #-}

foldlC :: Monad m => (a -> b -> a) -> a -> Sink b m a
foldlC f z = sink z ((return .) . f)
{-# INLINE foldlC #-}

foldlCE :: (Monad m, MonoFoldable mono)
        => (a -> Element mono -> a) -> a -> Sink mono m a
foldlCE f = foldlC (ofoldl' f)
{-# INLINE foldlCE #-}

foldMapC :: (Monad m, Monoid b) => (a -> b) -> Sink a m b
foldMapC f = foldlC (\acc x -> acc `mappend` f x) mempty
{-# INLINE foldMapC #-}

foldMapCE :: (Monad m, MonoFoldable mono, Monoid w)
          => (Element mono -> w) -> Sink mono m w
foldMapCE = foldMapC . ofoldMap
{-# INLINE foldMapCE #-}

allC :: Monad m => (a -> Bool) -> Sink a m Bool
allC f = liftM getAll `liftM` foldMapC (All . f)
{-# INLINE allC #-}

allCE :: (Monad m, MonoFoldable mono)
      => (Element mono -> Bool) -> Sink mono m Bool
allCE = allC . oall
{-# INLINE allCE #-}

anyC :: Monad m => (a -> Bool) -> Sink a m Bool
anyC f = liftM getAny `liftM` foldMapC (Any . f)
{-# INLINE anyC #-}

anyCE :: (Monad m, MonoFoldable mono)
      => (Element mono -> Bool) -> Sink mono m Bool
anyCE = anyC . oany
{-# INLINE anyCE #-}

andC :: Monad m => Sink Bool m Bool
andC = allC id
{-# INLINE andC #-}

andCE :: (Monad m, MonoFoldable mono, Element mono ~ Bool)
      => Sink mono m Bool
andCE = allCE id
{-# INLINE andCE #-}

orC :: Monad m => Sink Bool m Bool
orC = anyC id
{-# INLINE orC #-}

orCE :: (Monad m, MonoFoldable mono, Element mono ~ Bool)
     => Sink mono m Bool
orCE = anyCE id
{-# INLINE orCE #-}

elemC :: (Monad m, Eq a) => a -> Sink a m Bool
elemC x = anyC (== x)
{-# INLINE elemC #-}

elemCE :: (Monad m, EqSequence seq) => Element seq -> Sink seq m Bool
elemCE = anyC . Seq.elem
{-# INLINE elemCE #-}

notElemC :: (Monad m, Eq a) => a -> Sink a m Bool
notElemC x = allC (/= x)
{-# INLINE notElemC #-}

notElemCE :: (Monad m, EqSequence seq) => Element seq -> Sink seq m Bool
notElemCE = allC . Seq.notElem
{-# INLINE notElemCE #-}

produceList :: Monad m => ([a] -> b) -> Sink a m b
produceList f =
    liftM (f . ($ [])) . sink id (\front x -> return (front . (x:)))
{-# INLINE produceList #-}

sinkLazy :: (Monad m, LazySequence lazy strict) => Sink strict m lazy
sinkLazy = produceList fromChunks
-- {-# INLINE sinkLazy #-}

sinkList :: Monad m => Sink a m [a]
sinkList = produceList id
{-# INLINE sinkList #-}

sinkVector :: (MonadBase base m, Vector v a, PrimMonad base)
           => Sink a m (v a)
sinkVector = undefined

sinkVectorN :: (MonadBase base m, Vector v a, PrimMonad base)
            => Int -> Sink a m (v a)
sinkVectorN = undefined

sinkBuilder :: (Monad m, Monoid builder, ToBuilder a builder)
            => Sink a m builder
sinkBuilder = foldMapC toBuilder
{-# INLINE sinkBuilder #-}

sinkLazyBuilder :: (Monad m, Monoid builder, ToBuilder a builder,
                    Builder builder lazy)
                => Sink a m lazy
sinkLazyBuilder = liftM builderToLazy . foldMapC toBuilder
{-# INLINE sinkLazyBuilder #-}

sinkNull :: Monad m => Sink a m ()
sinkNull _ = return ()
{-# INLINE sinkNull #-}

awaitNonNull :: (Monad m, MonoFoldable a) => Conduit a m (Maybe (NonNull a))
awaitNonNull = conduit $ \r yield x ->
    maybe (return r) (yield r . Just) (NonNull.fromNullable x)
{-# INLINE awaitNonNull #-}

headCE :: (Monad m, IsSequence seq) => Sink seq m (Maybe (Element seq))
headCE = undefined
{-# INLINE headCE #-}

-- jww (2014-06-07): These two cannot be implemented without leftover support.
-- peekC :: Monad m => Sink a m (Maybe a)
-- peekC = undefined

-- peekCE :: (Monad m, MonoFoldable mono) => Sink mono m (Maybe (Element mono))
-- peekCE = undefined

lastC :: Monad m => Sink a m (Maybe a)
lastC = sink Nothing (const (return . Just))
{-# INLINE lastC #-}

lastCE :: (Monad m, IsSequence seq) => Sink seq m (Maybe (Element seq))
lastCE = undefined
{-# INLINE lastCE #-}

lengthC :: (Monad m, Num len) => Sink a m len
lengthC = foldlC (\x _ -> x + 1) 0
{-# INLINE lengthC #-}

lengthCE :: (Monad m, Num len, MonoFoldable mono) => Sink mono m len
lengthCE = foldlC (\x y -> x + fromIntegral (olength y)) 0
{-# INLINE lengthCE #-}

lengthIfC :: (Monad m, Num len) => (a -> Bool) -> Sink a m len
lengthIfC f = foldlC (\cnt a -> if f a then cnt + 1 else cnt) 0
{-# INLINE lengthIfC #-}

lengthIfCE :: (Monad m, Num len, MonoFoldable mono)
           => (Element mono -> Bool) -> Sink mono m len
lengthIfCE f = foldlCE (\cnt a -> if f a then cnt + 1 else cnt) 0
{-# INLINE lengthIfCE #-}

maximumC :: (Monad m, Ord a) => Sink a m (Maybe a)
maximumC = sink Nothing $ \r y -> return $ Just $ maybe y (max y) r
{-# INLINE maximumC #-}

maximumCE :: (Monad m, OrdSequence seq) => Sink seq m (Maybe (Element seq))
maximumCE = undefined
{-# INLINE maximumCE #-}

minimumC :: (Monad m, Ord a) => Sink a m (Maybe a)
minimumC = sink Nothing $ \r y -> return $ Just $ maybe y (min y) r
{-# INLINE minimumC #-}

minimumCE :: (Monad m, OrdSequence seq) => Sink seq m (Maybe (Element seq))
minimumCE = undefined
{-# INLINE minimumCE #-}

-- jww (2014-06-07): These two cannot be implemented without leftover support.
-- nullC :: Monad m => Sink a m Bool
-- nullC = undefined

-- nullCE :: (Monad m, MonoFoldable mono) => Sink mono m Bool
-- nullCE = undefined

sumC :: (Monad m, Num a) => Sink a m a
sumC = foldlC (+) 0
{-# INLINE sumC #-}

sumCE :: (Monad m, MonoFoldable mono, Num (Element mono))
      => Sink mono m (Element mono)
sumCE = undefined
{-# INLINE sumCE #-}

productC :: (Monad m, Num a) => Sink a m a
productC = foldlC (*) 1
{-# INLINE productC #-}

productCE :: (Monad m, MonoFoldable mono, Num (Element mono))
          => Sink mono m (Element mono)
productCE = undefined
{-# INLINE productCE #-}

findC :: Monad m => (a -> Bool) -> Sink a m (Maybe a)
findC f = sink Nothing $ \r x -> if f x then left (Just x) else return r
{-# INLINE findC #-}

mapM_C :: Monad m => (a -> m ()) -> Sink a m ()
mapM_C f = sink () (const $ lift . f)
{-# INLINE mapM_C #-}

mapM_CE :: (Monad m, MonoFoldable mono)
        => (Element mono -> m ()) -> Sink mono m ()
mapM_CE = undefined
{-# INLINE mapM_CE #-}

foldMC :: Monad m => (a -> b -> m a) -> a -> Sink b m a
foldMC f = flip sink ((lift .) . f)
{-# INLINE foldMC #-}

foldMCE :: (Monad m, MonoFoldable mono)
        => (a -> Element mono -> m a) -> a -> Sink mono m a
foldMCE = undefined
{-# INLINE foldMCE #-}

foldMapMC :: (Monad m, Monoid w) => (a -> m w) -> Sink a m w
foldMapMC f = foldMC (\acc x -> (acc `mappend`) `liftM` f x) mempty
{-# INLINE foldMapMC #-}

foldMapMCE :: (Monad m, MonoFoldable mono, Monoid w)
           => (Element mono -> m w) -> Sink mono m w
foldMapMCE = undefined
{-# INLINE foldMapMCE #-}

sinkFile :: (MonadBaseControl IO m, MonadIO m, IOData a)
         => FilePath -> Sink a m ()
sinkFile fp = sinkIOHandle (liftIO $ openFile fp WriteMode)
{-# INLINE sinkFile #-}

sinkHandle :: (MonadIO m, IOData a) => Handle -> Sink a m ()
sinkHandle = mapM_C . hPut
{-# INLINE sinkHandle #-}

sinkIOHandle :: (MonadBaseControl IO m, MonadIO m, IOData a)
             => IO Handle -> Sink a m ()
sinkIOHandle alloc =
    bracket (liftIO alloc) (liftIO . hClose) . flip sinkHandle
{-# INLINE sinkIOHandle #-}

printC :: (Show a, MonadIO m) => Sink a m ()
printC = mapM_C (liftIO . print)
{-# INLINE printC #-}

stdoutC :: (MonadIO m, IOData a) => Sink a m ()
stdoutC = sinkHandle stdout
{-# INLINE stdoutC #-}

stderrC :: (MonadIO m, IOData a) => Sink a m ()
stderrC = sinkHandle stderr
{-# INLINE stderrC #-}

mapC :: Monad m => (a -> b) -> Conduit a m b
mapC = fmap
{-# INLINE mapC #-}

mapCE :: (Monad m, Functor f) => (a -> b) -> Conduit (f a) m (f b)
mapCE = undefined
{-# INLINE mapCE #-}

omapCE :: (Monad m, MonoFunctor mono)
       => (Element mono -> Element mono) -> Conduit mono m mono
omapCE = undefined
{-# INLINE omapCE #-}

concatMapC :: (Monad m, MonoFoldable mono)
           => (a -> mono) -> Conduit a m (Element mono)
concatMapC f = conduit $ \r yield -> ofoldlM yield r . f
{-# INLINE concatMapC #-}

concatMapCE :: (Monad m, MonoFoldable mono, Monoid w)
            => (Element mono -> w) -> Conduit mono m w
concatMapCE = undefined
{-# INLINE concatMapCE #-}

takeC :: Monad m => Int -> Conduit a m a
takeC n = conduitWith n go
  where
    go (z', n') yield x
        | n' > 1    = next
        | n' > 0    = left =<< next
        | otherwise = left (z', 0)
      where
        next = fmap pred <$> yield z' x

{-
takeCGen :: Monad m
         => Int -> FoldT (r, Int) (EitherT (r, Int) m) a
         -> FoldT r (EitherT r m) a
takeCGen n = foldWith' n go
  where
    go (z', n') yield x
        | n' > 1    = next
        | n' > 0    = left =<< next
        | otherwise = left (z', 0)
      where
        next = fmap pred <$> yield z' x
-}

takeCE :: (Monad m, IsSequence seq) => Index seq -> Conduit seq m seq
takeCE = undefined

-- | This function reads one more element than it yields, which would be a
--   problem if Sinks were monadic, as they are in conduit or pipes.  There is
--   no such concept as "resuming where the last conduit left off" in this
--   library.
takeWhileC :: Monad m => (a -> Bool) -> Conduit a m a
takeWhileC f = conduitWith f go
  where
    go (z', k) yield x | k x = yield z' x
    go (z', _) _ _           = left (z', const False)

takeWhileCE :: (Monad m, IsSequence seq)
            => (Element seq -> Bool) -> Conduit seq m seq
takeWhileCE = undefined

takeExactlyC :: Monad m => Int -> Conduit a m b -> Conduit a m b
takeExactlyC = undefined

takeExactlyCE :: (Monad m, IsSequence a)
              => Index a -> Conduit a m b -> Conduit a m b
takeExactlyCE = undefined

concatC :: (Monad m, MonoFoldable mono) => Conduit mono m (Element mono)
concatC = undefined

filterC :: Monad m => (a -> Bool) -> Conduit a m a
filterC f = awaitForever $ \x -> if f x then return x else skip
{-# INLINE filterC #-}

filterCE :: (IsSequence seq, Monad m)
         => (Element seq -> Bool) -> Conduit seq m seq
filterCE = undefined
{-# INLINE filterCE #-}

mapWhileC :: Monad m => (a -> Maybe b) -> Conduit a m b
mapWhileC f = awaitForever $ \x -> case f x of Just y -> return y; _ -> close
{-# INLINE mapWhileC #-}

conduitVector :: (MonadBase base m, Vector v a, PrimMonad base)
              => Int -> Conduit a m (v a)
conduitVector = undefined

scanlC :: Monad m => (a -> b -> a) -> a -> Conduit b m a
scanlC = undefined

concatMapAccumC :: Monad m => (a -> accum -> (accum, [b])) -> accum -> Conduit a m b
concatMapAccumC = undefined

intersperseC :: Monad m => a -> Source m a -> Source m a
intersperseC s src = source $ \z yield -> EitherT $ do
    eres <- runEitherT $ runSource src (Nothing, z) $ \(my, r) x ->
        case my of
            Nothing -> return (Just x, r)
            Just y  -> do
                r' <- rewrap (Nothing,) $ yield r y
                rewrap (Just x,) $ yield (snd r') s
    case eres of
        Left (_, r)        -> return $ Left r
        Right (Nothing, r) -> return $ Right r
        Right (Just x, r)  -> runEitherT $ yield r x

encodeBase64C :: Monad m => Conduit ByteString m ByteString
encodeBase64C = undefined

decodeBase64C :: Monad m => Conduit ByteString m ByteString
decodeBase64C = undefined

encodeBase64URLC :: Monad m => Conduit ByteString m ByteString
encodeBase64URLC = undefined

decodeBase64URLC :: Monad m => Conduit ByteString m ByteString
decodeBase64URLC = undefined

encodeBase16C :: Monad m => Conduit ByteString m ByteString
encodeBase16C = undefined

decodeBase16C :: Monad m => Conduit ByteString m ByteString
decodeBase16C = undefined

mapMC :: Monad m => (a -> m b) -> Conduit a m b
mapMC f = (>>= lift . f)
{-# INLINE mapMC #-}

mapMCE :: (Monad m, Traversable f) => (a -> m b) -> Conduit (f a) m (f b)
mapMCE = undefined
{-# INLINE mapMCE #-}

omapMCE :: (Monad m, MonoTraversable mono)
        => (Element mono -> m (Element mono)) -> Conduit mono m mono
omapMCE = undefined

concatMapMC :: (Monad m, MonoFoldable mono)
            => (a -> m mono) -> Conduit a m (Element mono)
concatMapMC f = awaitForever $ yieldMany <=< lift . f

filterMC :: Monad m => (a -> m Bool) -> Conduit a m a
filterMC f = awaitForever $ \x -> do
    res <- lift $ f x
    if res
        then return x
        else skip
{-# INLINE filterMC #-}

filterMCE :: (Monad m, IsSequence seq)
          => (Element seq -> m Bool) -> Conduit seq m seq
filterMCE = undefined

iterMC :: Monad m => (a -> m ()) -> Conduit a m a
iterMC = undefined

scanlMC :: Monad m => (a -> b -> m a) -> a -> Conduit b m a
scanlMC = undefined

concatMapAccumMC :: Monad m
                 => (a -> accum -> m (accum, [b])) -> accum -> Conduit a m b
concatMapAccumMC = undefined

encodeUtf8C :: (Monad m, Utf8 text binary) => Conduit text m binary
encodeUtf8C = mapC encodeUtf8
{-# INLINE encodeUtf8C #-}

decodeUtf8C :: MonadThrow m => Conduit ByteString m Text
decodeUtf8C = undefined

lineC :: (Monad m, IsSequence seq, Element seq ~ Char)
      => Conduit seq m o -> Conduit seq m o
lineC = undefined

lineAsciiC :: (Monad m, IsSequence seq, Element seq ~ Word8)
           => Conduit seq m o -> Conduit seq m o
lineAsciiC = undefined

unlinesC :: (Monad m, IsSequence seq, Element seq ~ Char)
         => Conduit seq m seq
unlinesC = concatMapC (: [Seq.singleton '\n'])
{-# INLINE unlinesC #-}

unlinesAsciiC :: (Monad m, IsSequence seq, Element seq ~ Word8)
              => Conduit seq m seq
unlinesAsciiC = concatMapC (: [Seq.singleton 10])
{-# INLINE unlinesAsciiC #-}

linesUnboundedC_ :: forall m seq. (Monad m, IsSequence seq, Eq (Element seq))
                 => Element seq -> Conduit seq m seq
linesUnboundedC_ sep src = source $ \z yield -> EitherT $ do
    eres <- runEitherT $ runSource src (z, n) (go yield)
    case eres of
        Left (r, _)  -> return $ Left r
        Right (r, t)
            | onull t   -> return $ Right r
            | otherwise -> runEitherT $ yield r t
  where
    n = Seq.fromList []

    go :: (r -> seq -> EitherT r m r) -> (r, seq) -> seq
       -> EitherT (r, seq) m (r, seq)
    go yield = loop
      where
        loop (r, t') t
            | onull y = return (r, t <> t')
            | otherwise = do
                r' <- rewrap (, n) $ yield r (t' <> x)
                loop r' (Seq.drop 1 y)
          where
            (x, y) = Seq.break (== sep) t

linesUnboundedC :: (Monad m, IsSequence seq, Element seq ~ Char)
                => Conduit seq m seq
linesUnboundedC = linesUnboundedC_ '\n'
{-# INLINE linesUnboundedC #-}

linesUnboundedAsciiC :: (Monad m, IsSequence seq, Element seq ~ Word8)
                     => Conduit seq m seq
linesUnboundedAsciiC = linesUnboundedC_ 10
{-# INLINE linesUnboundedAsciiC #-}

linesC :: (Monad m, IsSequence seq, Element seq ~ Char)
                => Conduit seq m seq
linesC = linesUnboundedC
{-# INLINE linesC #-}

linesAsciiC :: (Monad m, IsSequence seq, Element seq ~ Word8)
                     => Conduit seq m seq
linesAsciiC = linesUnboundedAsciiC
{-# INLINE linesAsciiC #-}

-- | Zip sinks together.  This function may be used multiple times:
--
-- >>> let mySink s = sink () $ \() x -> liftIO $ print $ s <> show x
-- >>> zipSinks sinkList (zipSinks (mySink "foo") (mySink "bar")) $ yieldMany [1,2,3]
-- "foo: 1"
-- "bar: 1"
-- "foo: 2"
-- "bar: 2"
-- "foo: 3"
-- "bar: 3"
-- ([1,2,3],((),()))
--
-- Note that the two sinks are run concurrently, so beware of race conditions
-- if they interact with the same resource.
zipSinks :: forall a m r r'. (MonadBaseControl IO m, MonadIO m)
         => Sink a m r -> Sink a m r' -> Sink a m (r, r')
zipSinks sink1 sink2 src = do
    x <- liftIO newEmptyMVar
    y <- liftIO newEmptyMVar
    withAsync (sink1 $ sourceMaybeMVar x) $ \a ->
        withAsync (sink2 $ sourceMaybeMVar y) $ \b -> do
            _ <- runEitherT $ runSource src () $ \() val -> do
                liftIO $ putMVar x (Just val)
                liftIO $ putMVar y (Just val)
            liftIO $ putMVar x Nothing
            liftIO $ putMVar y Nothing
            waitBoth a b

-- | Keep taking from an @MVar (Maybe a)@ until it yields 'Nothing'.
sourceMaybeMVar :: forall m a. MonadIO m => MVar (Maybe a) -> Source m a
sourceMaybeMVar var = source go
  where
    go :: r -> (r -> a -> EitherT r m r) -> EitherT r m r
    go z yield = loop z
      where
        loop r = do
            mx <- liftIO $ takeMVar var
            case mx of
                Nothing -> return r
                Just x  -> loop =<< yield r x

-- | Keep taking from an @TMVar (Maybe a)@ until it yields 'Nothing'.
sourceMaybeTMVar :: forall a. TMVar (Maybe a) -> Source STM a
sourceMaybeTMVar var = source go
  where
    go :: r -> (r -> a -> EitherT r STM r) -> EitherT r STM r
    go z yield = loop z
      where
        loop r = do
            mx <- lift $ takeTMVar var
            case mx of
                Nothing -> return r
                Just x  -> loop =<< yield r x

newtype ZipSink a m r = ZipSink { getZipSink :: Source m a -> m r }

instance Monad m => Functor (ZipSink a m) where
    fmap f (ZipSink k) = ZipSink $ liftM f . k

instance Monad m => Applicative (ZipSink a m) where
    pure x = ZipSink $ \_ -> return x
    ZipSink f <*> ZipSink x = ZipSink $ \await -> f await `ap` x await

-- | Send incoming values to all of the @Sink@ providing, and ultimately
--   coalesce together all return values.
--
-- Implemented on top of @ZipSink@, see that data type for more details.
sequenceSinks :: (Traversable f, Monad m) => f (Sink a m r) -> Sink a m (f r)
sequenceSinks = getZipSink . sequenceA . fmap ZipSink
{-# INLINE sequenceSinks #-}

asyncC :: (MonadBaseControl IO m, Monad m)
       => (a -> m b) -> Conduit a m (Async (StM m b))
asyncC f = awaitForever $ lift . async . f
{-# INLINE asyncC #-}

-- | Convert a 'Control.Foldl.FoldM' fold abstraction into a Sink.
--
--   NOTE: This requires ImpredicativeTypes in the code that uses it.
--
-- >>> fromFoldM (FoldM ((return .) . (+)) (return 0) return) $ yieldMany [1..10]
-- 55
fromFoldM :: Monad m => FoldM m a b -> Source m a -> m b
fromFoldM (FoldM step initial final) src = do
    r <- initial
    final =<< sink r ((lift .) . step) src
{-# INLINE fromFoldM #-}

-- | Convert a Sink into a 'Control.Foldl.FoldM', passing it into a
--   continuation.
--
-- >>> toFoldM sumC (\f -> Control.Foldl.foldM f [1..10])
-- 55
toFoldM :: Monad m
        => Sink a m r -> (forall s. FoldM (EitherT s m) a s -> EitherT s m s) -> m r
toFoldM s f = s $ source $ \k yield -> f $ FoldM yield (return k) return
{-# INLINE toFoldM #-}

sourceSTM :: forall container a. (container a -> STM a)
          -> (container a -> STM Bool)
          -> container a
          -> Source STM a
sourceSTM getter tester chan = source go
  where
    go :: r -> (r -> a -> EitherT r STM r) -> EitherT r STM r
    go z yield = loop z
      where
        loop r = do
            x  <- lift $ getter chan
            r' <- yield r x
            mt <- lift $ tester chan
            if mt
                then return r'
                else loop r'

-- | A Source for exhausting a TChan, but blocks if it is initially empty.
sourceTChan :: forall a. TChan a -> Source STM a
sourceTChan = sourceSTM readTChan isEmptyTChan
{-# INLINE sourceTChan #-}

sourceTQueue :: forall a. TQueue a -> Source STM a
sourceTQueue = sourceSTM readTQueue isEmptyTQueue
{-# INLINE sourceTQueue #-}

sourceTBQueue :: forall a. TBQueue a -> Source STM a
sourceTBQueue = sourceSTM readTBQueue isEmptyTBQueue
{-# INLINE sourceTBQueue #-}

untilMC :: forall m a. Monad m => m a -> m Bool -> Source m a
untilMC m f = source go
  where
    go :: r -> (r -> a -> EitherT r m r) -> EitherT r m r
    go z yield = loop z
      where
        loop r = do
            x  <- lift m
            r' <- yield r x
            c  <- lift f
            if c then loop r' else return r'

whileMC :: forall m a. Monad m => m Bool -> m a -> Source m a
whileMC f m = source go
  where
    go :: r -> (r -> a -> EitherT r m r) -> EitherT r m r
    go z yield = loop z
      where
        loop r = do
            c <- lift f
            if c
                then lift m >>= yield r >>= loop
                else return r
