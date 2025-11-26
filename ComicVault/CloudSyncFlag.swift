//
//  CloudSyncFlag.swift
//  ComicVault
//
//  File created on 10/27/25 by ApogeeINVENT, a software engineering company, in collaboration with the CryptoComics team.
//  Developers: Matthew Russell & GPT-5 Thinking
//
//  Description: Compile-time/runtime flags enabling or disabling CloudSync features.
//

#if USE_CLOUDSYNC
public let CLOUDSYNC_ENABLED = true
#else
public let CLOUDSYNC_ENABLED = false
#endif
