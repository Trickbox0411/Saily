//
//  AuxiliaryExecute.swift
//  MyYearWithGit
//
//  Created by Lakr Aream on 2021/11/27.
//

import Foundation

/// Execute command or shell with posix, shared with AuxiliaryExecute.local
public class AuxiliaryExecute {
    /// we do not recommend you to subclass this singleton
    public static let local = AuxiliaryExecute()

    // if binary not found when you call the shell api
    // we will take some time to rebuild the bianry table each time
    // -->>> this is a time-heavy-task
    // so use binaryLocationFor(command:) to cache it if needed

    // system path
    var currentPath: [String] = []
    // system binary table
    var binaryTable: [String: String] = [:]

    // for you to put your own search path
    var extraSearchPath: [String] = []
    // for you to set your own binary table and will be used firstly
    // if you set nil here
    // -> we will return nil even the binary found in system path
    var overwriteTable: [String: String?] = [:]

    // this value is used when providing 0 or negative timeout paramete
    static let maxTimeoutValue: Double = 2_147_483_647

    /// when reading from file pipe, must called from async queue
    static let pipeControlQueue = DispatchQueue(
        label: "wiki.qaq.AuxiliaryExecute.pipeRead",
        attributes: .concurrent
    )

    /// when killing process or monitoring events from process, must called from async queue
    /// we are making this queue serial queue so won't called at the same time when timeout
    static let processControlQueue = DispatchQueue(
        label: "wiki.qaq.AuxiliaryExecute.processControl",
        attributes: []
    )

    /// used for setting binary table, avoid crash
    let lock = NSLock()

    /// nope!
    private init() {
        // no need to setup binary table
        // we will make call to it when you call the shell api
        // if you only use the spawn api
        // we don't need to setup the hole table cause it‘s time-heavy-task
    }

    /// Execution Error, do the localization your self
    public enum ExecuteError: Error, LocalizedError, Codable {
        // not found in path
        case commandNotFound
        // invalid, may be missing, wrong permission or any other reason
        case commandInvalid
        // fcntl failed
        case openFilePipeFailed
        // posix failed
        case posixSpawnFailed
        // waitpid failed
        case waitPidFailed
        // timeout when execute
        case timeout
    }

    /// Execution Recipe
    public struct ExecuteRecipe: Codable {
        // exit code, usually 0 - 255 by system
        // -1 means something bad happened, set by us for convince
        public let exitCode: Int
        // process pid that was when it is alive
        // -1 means spawn failed in some situation
        public let pid: Int
        // wait result for final waitpid inside block at
        // processSource - eventMask.exit, usually is pid
        // -1 for other cases
        public let wait: Int
        // any error from us, not the command it self
        // DOES NOT MEAN THAT THE COMMAND DONE WELL
        public let error: ExecuteError?
        // stdout
        public let stdout: String
        // stderr
        public let stderr: String

        /// General initialization of recipe object
        /// - Parameters:
        ///   - exitCode: code when process exit
        ///   - pid: pid when process alive
        ///   - wait: wait result on waitpid
        ///   - error: error if any
        ///   - stdout: stdout
        ///   - stderr: stderr
        init(
            exitCode: Int,
            pid: Int,
            wait: Int,
            error: AuxiliaryExecute.ExecuteError?,
            stdout: String,
            stderr: String
        ) {
            self.exitCode = exitCode
            self.pid = pid
            self.wait = wait
            self.error = error
            self.stdout = stdout
            self.stderr = stderr
        }

        /// Template for making failure recipe
        /// - Parameters:
        ///   - exitCode: default -1
        ///   - pid: default -1
        ///   - wait: default -1
        ///   - error: error
        ///   - stdout: default empty
        ///   - stderr: default empty
        static func failure(
            exitCode: Int = -1,
            pid: Int = -1,
            wait: Int = -1,
            error: AuxiliaryExecute.ExecuteError?,
            stdout: String = "",
            stderr: String = ""
        ) -> ExecuteRecipe {
            .init(
                exitCode: exitCode,
                pid: pid,
                wait: wait,
                error: error,
                stdout: stdout,
                stderr: stderr
            )
        }
    }
}
