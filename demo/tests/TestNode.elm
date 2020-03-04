module TestNode exposing (..)

import Array
import Expect
import Rte.Model
    exposing
        ( Annotation
        , ChildNodes(..)
        , EditorAttribute(..)
        , EditorFragment(..)
        , EditorInlineLeaf(..)
        , EditorNode(..)
        , Mark
        , NodePath
        , inlineLeafArray
        , selectableAnnotation
        )
import Rte.Node
    exposing
        ( allRange
        , anyRange
        , concatMap
        , findAncestor
        , findBackwardFrom
        , findBackwardFromExclusive
        , findForwardFrom
        , findForwardFromExclusive
        , findTextBlockNodeAncestor
        , foldl
        , foldr
        , indexedFoldl
        , indexedFoldr
        , indexedMap
        , isSelectable
        , map
        , next
        , nodeAt
        , previous
        , removeInRange
        , removeNodeAndEmptyParents
        , replace
        , replaceWithFragment
        , splitBlockAtPathAndOffset
        , splitTextLeaf
        )
import Rte.NodePath exposing (toString)
import Set
import Test exposing (Test, describe, test)


rootNode =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        BlockArray <|
            Array.fromList [ pNode ]
    }


pNode =
    { parameters = { name = "p", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ textNode1, textNode2 ]
    }


textNode1Contents =
    { marks = [], text = "sample1", annotations = Set.empty }


textNode1 =
    TextLeaf textNode1Contents


textNode2Contents =
    { marks = [], text = "sample2", annotations = Set.empty }


textNode2 =
    TextLeaf textNode2Contents


testNodeAt : Test
testNodeAt =
    describe "Tests the function which finds a node given a node path and a block node"
        [ test "Test that we can find the root node" <|
            \_ ->
                Expect.equal (Just (BlockNodeWrapper rootNode)) (nodeAt [] rootNode)
        , test "Test that we can find the p node" <|
            \_ ->
                Expect.equal (Just (BlockNodeWrapper pNode)) (nodeAt [ 0 ] rootNode)
        , test "Test that we can find the first text node" <|
            \_ ->
                Expect.equal (Just (InlineLeafWrapper textNode1)) (nodeAt [ 0, 0 ] rootNode)
        , test "Test that we can find the second text node" <|
            \_ ->
                Expect.equal (Just (InlineLeafWrapper textNode2)) (nodeAt [ 0, 1 ] rootNode)
        , test "Test that invalid paths return no result" <|
            \_ ->
                Expect.equal Nothing (nodeAt [ 0, 2 ] rootNode)
        , test "Test that invalid paths that are too long return no result" <|
            \_ ->
                Expect.equal Nothing (nodeAt [ 0, 0, 0 ] rootNode)
        ]


nodePathList : NodePath -> EditorNode -> List NodePath -> List NodePath
nodePathList path _ list =
    path :: list


nodeNameOrTextValue : NodePath -> EditorNode -> List String -> List String
nodeNameOrTextValue _ node list =
    (case node of
        BlockNodeWrapper bn ->
            bn.parameters.name

        InlineLeafWrapper il ->
            case il of
                TextLeaf tl ->
                    tl.text

                InlineLeaf p ->
                    p.parameters.name
    )
        :: list


testIndexedFoldr : Test
testIndexedFoldr =
    describe "Tests that indexFoldr works as expected"
        [ test "Test that the node paths are passed in as expected" <|
            \_ -> Expect.equal [ [], [ 0 ], [ 0, 0 ], [ 0, 1 ] ] (indexedFoldr nodePathList [] (BlockNodeWrapper rootNode))
        , test "Test that the nodes are passed in as expected" <|
            \_ -> Expect.equal [ "div", "p", "sample1", "sample2" ] (indexedFoldr nodeNameOrTextValue [] (BlockNodeWrapper rootNode))
        ]


testFoldr : Test
testFoldr =
    describe "Tests that foldr works as expected"
        [ test "Test that the nodes are passed in as expected" <|
            \_ -> Expect.equal [ "div", "p", "sample1", "sample2" ] (foldr (\x -> nodeNameOrTextValue [] x) [] (BlockNodeWrapper rootNode))
        ]


testIndexedFoldl : Test
testIndexedFoldl =
    describe "Tests that indexedFoldl works as expected"
        [ test "Test that the node paths are passed in as expected" <|
            \_ -> Expect.equal [ [ 0, 1 ], [ 0, 0 ], [ 0 ], [] ] (indexedFoldl nodePathList [] (BlockNodeWrapper rootNode))
        , test "Test that the nodes are passed in as expected" <|
            \_ -> Expect.equal [ "sample2", "sample1", "p", "div" ] (indexedFoldl nodeNameOrTextValue [] (BlockNodeWrapper rootNode))
        ]


testFoldl : Test
testFoldl =
    describe "Tests that foldl works as expected"
        [ test "Test that the nodes are passed in as expected" <|
            \_ -> Expect.equal [ "sample2", "sample1", "p", "div" ] (foldl (\x -> nodeNameOrTextValue [] x) [] (BlockNodeWrapper rootNode))
        ]


testIsSelectable : Test
testIsSelectable =
    describe "Tests that a node is selectable"
        [ test "Test that a text node is selectable" <|
            \_ -> Expect.equal True <| isSelectable (InlineLeafWrapper (TextLeaf { text = "", marks = [], annotations = Set.empty }))
        , test "Test that a element node with a selectable mark is selectable" <|
            \_ -> Expect.equal True <| isSelectable (BlockNodeWrapper { parameters = { name = "div", attributes = [], annotations = Set.fromList [ selectableAnnotation ] }, childNodes = Leaf })
        , test "Test that a element node without a selectable mark is not selectable" <|
            \_ -> Expect.equal False <| isSelectable (BlockNodeWrapper { parameters = { name = "div", attributes = [], annotations = Set.empty }, childNodes = Leaf })
        ]


setAnnotations : Annotation -> EditorNode -> EditorNode
setAnnotations mark node =
    let
        annotations =
            Set.fromList [ mark ]
    in
    case node of
        BlockNodeWrapper bn ->
            let
                params =
                    bn.parameters
            in
            BlockNodeWrapper { bn | parameters = { params | annotations = annotations } }

        InlineLeafWrapper il ->
            case il of
                TextLeaf tl ->
                    InlineLeafWrapper (TextLeaf { tl | annotations = annotations })

                InlineLeaf l ->
                    let
                        params =
                            l.parameters
                    in
                    InlineLeafWrapper (InlineLeaf { l | parameters = { params | annotations = annotations } })


dummyAnnotation =
    "__dummy__"


addDummyAnnotation : EditorNode -> EditorNode
addDummyAnnotation node =
    setAnnotations dummyAnnotation node


addPathAnnotation : NodePath -> EditorNode -> EditorNode
addPathAnnotation path node =
    let
        pathAnnotation =
            toString path
    in
    setAnnotations pathAnnotation node


rootNodeWithPathAnnotation =
    { parameters = { name = "div", attributes = [], annotations = Set.fromList [ "" ] }
    , childNodes =
        BlockArray <|
            Array.fromList [ pHtmlNodeWithPathAnnotation ]
    }


pHtmlNodeWithPathAnnotation =
    { parameters = { name = "p", attributes = [], annotations = Set.fromList [ "0" ] }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ textNode1WithPathAnnotation, textNode2WithPathAnnotation ]
    }


textNode1WithPathAnnotation =
    TextLeaf { marks = [], annotations = Set.fromList [ "0:0" ], text = "sample1" }


textNode2WithPathAnnotation =
    TextLeaf { marks = [], annotations = Set.fromList [ "0:1" ], text = "sample2" }


testIndexedMap : Test
testIndexedMap =
    describe "Tests that indexedMap works as expected"
        [ test "Test that node paths are passed in correctly" <|
            \_ ->
                Expect.equal (BlockNodeWrapper rootNodeWithPathAnnotation)
                    (indexedMap addPathAnnotation (BlockNodeWrapper rootNode))
        ]


rootNodeWithSameAnnotation =
    { parameters = { name = "div", attributes = [], annotations = Set.fromList [ dummyAnnotation ] }
    , childNodes =
        BlockArray <|
            Array.fromList [ pHtmlNodeWithSameAnnotation ]
    }


pHtmlNodeWithSameAnnotation =
    { parameters = { name = "p", attributes = [], annotations = Set.fromList [ dummyAnnotation ] }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ textNode1WithSameAnnotation, textNode2WithSameAnnotation ]
    }


textNode1WithSameAnnotation =
    TextLeaf { marks = [], annotations = Set.fromList [ dummyAnnotation ], text = "sample1" }


textNode2WithSameAnnotation =
    TextLeaf { marks = [], annotations = Set.fromList [ dummyAnnotation ], text = "sample2" }


testMap : Test
testMap =
    describe "Tests that map works as expected"
        [ test "Test that nodes are correctly modified" <|
            \_ ->
                Expect.equal (BlockNodeWrapper rootNodeWithSameAnnotation)
                    (map addDummyAnnotation (BlockNodeWrapper rootNode))
        ]


testFindTextBlockNodeAncestor : Test
testFindTextBlockNodeAncestor =
    describe "Tests that findTextBlockNodeAncestor works as expected"
        [ test "Tests that we can correct find a text block node ancestor" <|
            \_ ->
                Expect.equal (Just ( [ 0 ], pNode )) (findTextBlockNodeAncestor [ 0, 0 ] rootNode)
        , test "Tests that we return nothing if no text block can be found" <|
            \_ ->
                Expect.equal Nothing (findTextBlockNodeAncestor [ 0 ] rootNode)
        ]


testFindAncestor : Test
testFindAncestor =
    describe "Tests that findAncestor works as expected"
        [ test "Tests that we can return the root if it's an ancestor" <|
            \_ ->
                Expect.equal
                    (Just ( [], rootNode ))
                    (findAncestor (\n -> n.parameters.name == "div") [ 0, 0 ] rootNode)
        ]


findNodeAtPath : NodePath -> NodePath -> EditorNode -> Bool
findNodeAtPath path1 path2 _ =
    path1 == path2


findNodeWithName : String -> NodePath -> EditorNode -> Bool
findNodeWithName name _ node =
    case node of
        BlockNodeWrapper bn ->
            bn.parameters.name == name

        InlineLeafWrapper il ->
            case il of
                InlineLeaf l ->
                    l.parameters.name == name

                _ ->
                    False


testFindBackwardFrom : Test
testFindBackwardFrom =
    describe "Tests that findBackwardFrom works as expected"
        [ test "Tests that the path is correctly passed in" <|
            \_ ->
                Expect.equal (Just ( [ 0, 0 ], InlineLeafWrapper textNode1 ))
                    (findBackwardFrom (findNodeAtPath [ 0, 0 ]) [ 0, 1 ] rootNode)
        , test "Tests that the function includes the passed in path" <|
            \_ ->
                Expect.equal (Just ( [ 0, 0 ], InlineLeafWrapper textNode1 ))
                    (findBackwardFrom (findNodeAtPath [ 0, 0 ]) [ 0, 0 ] rootNode)
        , test "Tests that the function returns Nothing if nothing is found" <|
            \_ ->
                Expect.equal Nothing
                    (findBackwardFrom (findNodeAtPath [ 1, 0 ]) [ 0, 1 ] rootNode)
        , test "Tests that the function passes in the node parameter correctly" <|
            \_ ->
                Expect.equal (Just ( [], BlockNodeWrapper rootNode ))
                    (findBackwardFrom (findNodeWithName "div") [ 0, 1 ] rootNode)
        ]


testFindBackwardFromExclusive : Test
testFindBackwardFromExclusive =
    describe "Tests that findBackwardFromExclusive works as expected"
        [ test "Tests that the path is correctly passed in" <|
            \_ ->
                Expect.equal (Just ( [ 0, 0 ], InlineLeafWrapper textNode1 ))
                    (findBackwardFromExclusive (findNodeAtPath [ 0, 0 ]) [ 0, 1 ] rootNode)
        , test "Tests that the function excludes the passed in path" <|
            \_ ->
                Expect.equal Nothing
                    (findBackwardFromExclusive (findNodeAtPath [ 0, 0 ]) [ 0, 0 ] rootNode)
        , test "Tests that the function returns Nothing if nothing is found" <|
            \_ ->
                Expect.equal Nothing
                    (findBackwardFromExclusive (findNodeAtPath [ 1, 0 ]) [ 0, 1 ] rootNode)
        , test "Tests that the function passes in the node parameter correctly" <|
            \_ ->
                Expect.equal (Just ( [], BlockNodeWrapper rootNode ))
                    (findBackwardFromExclusive (findNodeWithName "div") [ 0, 1 ] rootNode)
        ]


testFindForwardFrom : Test
testFindForwardFrom =
    describe "Tests that findNodeForwardFrom works as expected"
        [ test "Tests that the path is correctly passed in" <|
            \_ ->
                Expect.equal (Just ( [ 0, 0 ], InlineLeafWrapper textNode1 ))
                    (findForwardFrom (findNodeAtPath [ 0, 0 ]) [ 0 ] rootNode)
        , test "Tests that the function includes the passed in path" <|
            \_ ->
                Expect.equal (Just ( [ 0, 0 ], InlineLeafWrapper textNode1 ))
                    (findForwardFrom (findNodeAtPath [ 0, 0 ]) [ 0, 0 ] rootNode)
        , test "Tests that the function returns Nothing if nothing is found" <|
            \_ ->
                Expect.equal Nothing
                    (findForwardFrom (findNodeAtPath [ 1, 0 ]) [ 0, 1 ] rootNode)
        , test "Tests that the function passes in the node parameter correctly" <|
            \_ ->
                Expect.equal (Just ( [], BlockNodeWrapper rootNode ))
                    (findForwardFrom (findNodeWithName "div") [] rootNode)
        ]


testFindForwardFromExclusive : Test
testFindForwardFromExclusive =
    describe "Tests that findNodeForwardFromExclusive works as expected"
        [ test "Tests that the path is correctly passed in" <|
            \_ ->
                Expect.equal (Just ( [ 0, 0 ], InlineLeafWrapper textNode1 ))
                    (findForwardFromExclusive (findNodeAtPath [ 0, 0 ]) [ 0 ] rootNode)
        , test "Tests that the function excludes the passed in path" <|
            \_ ->
                Expect.equal Nothing
                    (findForwardFromExclusive (findNodeAtPath [ 0, 0 ]) [ 0, 0 ] rootNode)
        , test "Tests that the function returns Nothing if nothing is found" <|
            \_ ->
                Expect.equal Nothing
                    (findForwardFromExclusive (findNodeAtPath [ 1, 0 ]) [ 0, 1 ] rootNode)
        , test "Tests that the function passes in the node parameter correctly" <|
            \_ ->
                Expect.equal (Just ( [ 0 ], BlockNodeWrapper pNode ))
                    (findForwardFromExclusive (findNodeWithName "p") [] rootNode)
        ]


testNext : Test
testNext =
    describe "Tests that next works as expected"
        [ test "Tests that we receive the next element from root" <|
            \_ ->
                Expect.equal (Just ( [ 0 ], BlockNodeWrapper pNode ))
                    (next [] rootNode)
        , test "Tests that we receive nothing after the last node" <|
            \_ ->
                Expect.equal Nothing
                    (next [ 0, 1 ] rootNode)
        ]


testPrevious : Test
testPrevious =
    describe "Tests that previous works as expected"
        [ test "Tests that we receive the previous element from root" <|
            \_ ->
                Expect.equal (Just ( [], BlockNodeWrapper rootNode ))
                    (previous [ 0 ] rootNode)
        , test "Tests that we receive nothing before the root node" <|
            \_ ->
                Expect.equal Nothing
                    (previous [] rootNode)
        ]


removedRootNode =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        BlockArray <|
            Array.fromList [ removedPHtmlNode ]
    }


removedPHtmlNode =
    { parameters = { name = "p", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ textNode2 ]
    }


removedRootAll =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        BlockArray <|
            Array.empty
    }


removedPHtmlNodeAll =
    { parameters = { name = "p", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.empty
    }


removedRootNodeRemovedPNodeAll =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        BlockArray <|
            Array.fromList [ removedPHtmlNodeAll ]
    }


testRemoveNodeAndEmptyParents : Test
testRemoveNodeAndEmptyParents =
    describe "Tests that removeNodeAndEmptyParents works as expected"
        [ test "Tests that we can remove a text node properly" <|
            \_ ->
                Expect.equal removedRootNode
                    (removeNodeAndEmptyParents [ 0, 0 ] rootNode)
        , test "Tests that we remove parents properly" <|
            \_ ->
                Expect.equal removedRootAll
                    (removeNodeAndEmptyParents [ 0, 0 ] removedRootNode)
        ]


testRemoveInRange : Test
testRemoveInRange =
    describe "Tests that removeInRange works as expected"
        [ test "Tests that we remove elements we want" <|
            \_ ->
                Expect.equal removedRootAll
                    (removeInRange [ 0 ] [ 0 ] rootNode)
        , test "Tests that we remove elements we want, part ii" <|
            \_ ->
                Expect.equal removedRootNodeRemovedPNodeAll
                    (removeInRange [ 0, 0 ] [ 0, 1 ] rootNode)
        ]


replaceRootPNode =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        BlockArray <|
            Array.fromList [ replacePNode ]
    }


replacePNode =
    { parameters = { name = "p", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ textNode2, textNode2 ]
    }


testReplace : Test
testReplace =
    describe "Tests that replace works as expected"
        [ test "Tests that we replace the element we want" <|
            \_ ->
                Expect.equal (Ok replaceRootPNode)
                    (replace [ 0, 0 ] (InlineLeafWrapper textNode2) rootNode)
        ]


testReplaceWithFragment : Test
testReplaceWithFragment =
    describe "Tests that replaceWithFragment works as expected"
        [ test "Tests that we replace the element we want" <|
            \_ ->
                Expect.equal (Ok replaceRootPNode)
                    (replaceWithFragment [ 0, 0 ] (InlineLeafFragment <| Array.fromList [ textNode2 ]) rootNode)
        ]


testAllRange : Test
testAllRange =
    describe "Tests that allRange works as expected"
        [ test "Tests that an empty range returns true" <|
            \_ -> Expect.equal True <| allRange (\_ -> False) [ 0, 1 ] [ 0, 0 ] rootNode
        , test "Tests that a single node range works as expected" <|
            \_ -> Expect.equal True <| allRange (\node -> node == BlockNodeWrapper pNode) [ 0 ] [ 0 ] rootNode
        , test "Tests that a node range with one false returns False" <|
            \_ -> Expect.equal False <| allRange (\node -> node == BlockNodeWrapper pNode) [ 0 ] [ 0, 0 ] rootNode
        ]


testAnyRange : Test
testAnyRange =
    describe "Tests that anyRange works as expected"
        [ test "Tests that an empty range returns false" <|
            \_ -> Expect.equal False <| anyRange (\_ -> False) [ 0, 1 ] [ 0, 0 ] rootNode
        , test "Tests that a single node range works as expected" <|
            \_ -> Expect.equal True <| anyRange (\node -> node == BlockNodeWrapper pNode) [ 0 ] [ 0 ] rootNode
        , test "Tests that a node range with one true value returns True" <|
            \_ -> Expect.equal True <| anyRange (\node -> node == BlockNodeWrapper pNode) [ 0 ] [ 0, 0 ] rootNode
        , test "Tests that a node range with no true values returns False" <|
            \_ -> Expect.equal False <| anyRange (\_ -> False) [ 0 ] [ 0, 1 ] rootNode
        ]


doubleRoot =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        BlockArray <|
            Array.fromList [ doublePNode, doublePNode ]
    }


doublePNode =
    { parameters = { name = "p", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ textNode1, textNode1, textNode2, textNode2 ]
    }


testConcatMap : Test
testConcatMap =
    describe "Tests that concatMap works as expected"
        [ test "Tests that the identity function returns the same node" <|
            \_ ->
                Expect.equal rootNode <| concatMap (\node -> [ node ]) rootNode
        , test "Tests that the double function returns the expected tree" <|
            \_ -> Expect.equal doubleRoot <| concatMap (\node -> [ node, node ]) rootNode
        ]


textLeafBeforeSplitContents =
    { marks = [], text = "sam", annotations = Set.empty }


textLeafAfterSplitContents =
    { marks = [], text = "ple1", annotations = Set.empty }


nodeBeforeTextLeafSplit =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ TextLeaf textLeafBeforeSplitContents ]
    }


nodeAfterTextLeafSplit =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ TextLeaf textLeafAfterSplitContents ]
    }


nodeWithTextLeafToSplit =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ textNode1 ]
    }


inlineImg =
    InlineLeaf { marks = [], parameters = { attributes = [], annotations = Set.empty, name = "img" } }


nodeAfterInlineLeafSplit =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ inlineImg ]
    }


nodeBeforeInlineLeafSplit =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes = inlineLeafArray <| Array.empty
    }


nodeWithInlineLeafToSplit =
    { parameters = { name = "div", attributes = [], annotations = Set.empty }
    , childNodes =
        inlineLeafArray <|
            Array.fromList [ inlineImg ]
    }


testSplitBlockAtPathAndOffset : Test
testSplitBlockAtPathAndOffset =
    describe "Tests that testSplitBlockAtPathAndOffset works as expected"
        [ test "Tests that you cannot split a block at an invalid path" <|
            \_ -> Expect.equal Nothing <| splitBlockAtPathAndOffset [ 1 ] 0 rootNode
        , test "Tests that splitting a block node uses the offset to split before" <|
            \_ -> Expect.equal (Just ( removedRootAll, rootNode )) <| splitBlockAtPathAndOffset [] 0 rootNode
        , test "Tests that splitting a block node uses the offset to split after" <|
            \_ -> Expect.equal (Just ( rootNode, removedRootAll )) <| splitBlockAtPathAndOffset [] 1 rootNode
        , test "Tests that splitting a text leaf works correctly" <|
            \_ -> Expect.equal (Just ( nodeBeforeTextLeafSplit, nodeAfterTextLeafSplit )) <| splitBlockAtPathAndOffset [ 0 ] 3 nodeWithTextLeafToSplit
        , test "Tests that splitting an inline leaf works correctly" <|
            \_ -> Expect.equal (Just ( nodeBeforeInlineLeafSplit, nodeAfterInlineLeafSplit )) <| splitBlockAtPathAndOffset [ 0 ] 0 nodeWithInlineLeafToSplit
        ]


testSplitTextLeaf : Test
testSplitTextLeaf =
    describe "Tests that splitTextLeaf works as expected"
        [ test "Tests that splitting a text leaf works as expected" <|
            \_ ->
                Expect.equal ( textLeafBeforeSplitContents, textLeafAfterSplitContents ) <|
                    splitTextLeaf 3 textNode1Contents
        ]